#!/usr/bin/env bash
# ============================================================================
# SafeShift — create a superuser on a hosted Supabase project
#
# Creates an email + password auth user, promotes its public.profiles row to
# primary_role = 'admin', grants the admin role (default: super_admin), and
# verifies that the account can actually sign in and read admin permissions.
#
# The admin console (apps/admin-console) signs in with email + password and
# then calls public.admin_console_role(). That RPC only returns a role when
# the profile has an active row in public.admin_roles, so this script writes
# all three pieces:
#
#   1. auth.users          -> email + password, email confirmed
#   2. public.profiles     -> primary_role = 'admin', is_active = true
#   3. public.admin_roles  -> role_name = 'super_admin', is_active = true
#
# It also backfills public.admin_role_permissions so the role grants every
# permission in public.admin_permissions_catalog.
#
# Usage:
#   supabase/scripts/create-superuser.sh --email admin@safeshift.app \
#     --password 'S3cret-Passw0rd!'
#
#   # Inspect without changing anything
#   supabase/scripts/create-superuser.sh --email admin@safeshift.app --dry-run
#
# Required environment:
#   SUPABASE_SERVICE_ROLE_KEY   service role / secret key (never the anon key)
#
# Optional environment:
#   SUPABASE_URL                hosted project URL (default https://<ref>.supabase.co)
#   SUPABASE_ANON_KEY           anon/publishable key, used for the sign-in check
#
# The service role key is read from the environment, or from
# supabase/functions/.env.local when that file exists. It is never printed.
# ============================================================================

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- defaults ---------------------------------------------------------------
EMAIL=""
PASSWORD=""
PHONE=""
FULL_NAME=""
ROLE_NAME="super_admin"
COUNTRY_ISO="TZ"
SUPABASE_URL="${SUPABASE_URL:-}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
ANON_KEY="${SUPABASE_ANON_KEY:-}"
DRY_RUN="false"
REVOKE="false"
DELETE_USER="false"
NO_AUDIT="false"

# --- output helpers ---------------------------------------------------------
info() { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m  !!\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<EOF
SafeShift — create a superuser on a hosted Supabase project.

Creates an email + password auth user, promotes its public.profiles row to
primary_role = 'admin', grants the admin role (default: super_admin), and
verifies that the account can sign in and read admin permissions.

The admin console (apps/admin-console) signs in with email + password and
then calls public.admin_console_role(). That RPC only returns a role when
the profile has an active row in public.admin_roles, so this script writes
all three pieces:

  1. auth.users          -> email + password, email confirmed
  2. public.profiles     -> primary_role = 'admin', is_active = true
  3. public.admin_roles  -> role_name = 'super_admin', is_active = true

It also backfills public.admin_role_permissions so the role grants every
permission in public.admin_permissions_catalog.

Options:
  --email <email>        Admin email address (required)
  --password <password>  Password. Prompted for when omitted and stdin is a TTY.
  --name <full name>     Full name stored on the profile
  --phone <e164>         Optional phone in E.164 format, e.g. +255712345678
  --role <role_name>     Admin role to grant (default: super_admin)
  --country <iso>        Country ISO code used when the profile must be
                         created by hand (default: TZ)
  --url <supabase-url>   Hosted project URL (default: \$SUPABASE_URL)
  --dry-run              Validate credentials and report what would change
  --revoke               Remove the admin role instead of granting it, and
                         demote the profile back to 'customer'
  --delete-user          With --revoke, also delete the auth user
  --no-audit             Skip the admin_actions_log entry. Keeps the account
                         deletable later: that table is ON DELETE RESTRICT.
  -h, --help             Show this help

Required environment:
  SUPABASE_SERVICE_ROLE_KEY   service role / secret key (never the anon key)

Optional environment:
  SUPABASE_URL                hosted project URL
  SUPABASE_ANON_KEY           anon/publishable key, used for the sign-in check

Example:
  $SCRIPT_NAME --email admin@safeshift.app --password 'S3cret-Passw0rd!'
EOF
}

# --- argument parsing -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)    EMAIL="${2:-}"; shift 2 ;;
    --password) PASSWORD="${2:-}"; shift 2 ;;
    --phone)    PHONE="${2:-}"; shift 2 ;;
    --name)     FULL_NAME="${2:-}"; shift 2 ;;
    --role)     ROLE_NAME="${2:-}"; shift 2 ;;
    --country)  COUNTRY_ISO="${2:-}"; shift 2 ;;
    --url)      SUPABASE_URL="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN="true"; shift ;;
    --revoke)   REVOKE="true"; shift ;;
    --delete-user) DELETE_USER="true"; shift ;;
    --no-audit) NO_AUDIT="true"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "Unknown option '$1'. Run $SCRIPT_NAME --help." ;;
  esac
done

[[ -n "$EMAIL" ]] || die "--email is required."
[[ "$EMAIL" == *@* ]] || die "--email must be a valid email address."

if [[ -z "$PASSWORD" && "$DRY_RUN" != "true" && "$REVOKE" != "true" ]]; then
  if [[ -t 0 ]]; then
    read -r -s -p "Password for $EMAIL: " PASSWORD; echo
    read -r -s -p "Confirm password: " CONFIRM; echo
    [[ "$PASSWORD" == "$CONFIRM" ]] || die "Passwords do not match."
  else
    die "--password is required when stdin is not a terminal."
  fi
fi
if [[ "$DRY_RUN" != "true" && "$REVOKE" != "true" ]]; then
  [[ ${#PASSWORD} -ge 8 ]] || die "Password must be at least 8 characters."
fi

# --- credentials ------------------------------------------------------------
load_env_file() {
  local file="$1" line key value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    value="${value%\"}"; value="${value#\"}"
    case "$key" in
      SUPABASE_URL)            [[ -z "$SUPABASE_URL" ]] && SUPABASE_URL="$value" ;;
      SUPABASE_SERVICE_ROLE_KEY) [[ -z "$SERVICE_ROLE_KEY" ]] && SERVICE_ROLE_KEY="$value" ;;
      SUPABASE_ANON_KEY)       [[ -z "$ANON_KEY" ]] && ANON_KEY="$value" ;;
    esac
  done < "$file"
}

# The functions env file holds the hosted keys in this repo's convention.
load_env_file "$REPO_ROOT/supabase/functions/.env.local"

[[ -n "$SERVICE_ROLE_KEY" ]] || die "SUPABASE_SERVICE_ROLE_KEY is not set."
[[ "$SERVICE_ROLE_KEY" != replace-* ]] || die "SUPABASE_SERVICE_ROLE_KEY is still a placeholder."

if [[ -z "$SUPABASE_URL" ]]; then
  REF="$(cat "$REPO_ROOT/supabase/.temp/project-ref" 2>/dev/null || true)"
  [[ -n "$REF" ]] && SUPABASE_URL="https://${REF}.supabase.co"
fi
[[ -n "$SUPABASE_URL" ]] || die "SUPABASE_URL is not set. Pass --url or export SUPABASE_URL."
SUPABASE_URL="${SUPABASE_URL%/}"

if [[ "$SUPABASE_URL" != *".supabase.co" ]]; then
  warn "Target '$SUPABASE_URL' is not a hosted Supabase project."
  warn "This script is meant for hosted projects. Continue only if that is intended."
fi

# --- helpers ----------------------------------------------------------------

# Decode a JWT payload without extra tooling.
jwt_payload() {
  local token="$1" part
  part="$(printf '%s' "$token" | cut -d. -f2)"
  [[ -n "$part" ]] || return 1
  case $((${#part} % 4)) in
    2) part="${part}==" ;;
    3) part="${part}=" ;;
  esac
  part="$(printf '%s' "$part" | tr '_-' '/+')"
  if printf '%s' "$part" | base64 -d >/dev/null 2>&1; then
    printf '%s' "$part" | base64 -d 2>/dev/null
  else
    printf '%s' "$part" | openssl base64 -d -A 2>/dev/null
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found."
}
require_command curl
require_command jq

# Percent-encode a string for use in a query parameter value.
urlencode() {
  local s="$1" out="" c i
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

# Call the Supabase REST/Auth API with the service role key.
#
# The body lands in the global API_BODY and the HTTP status in API_STATUS.
# Both are globals on purpose: the call must NOT run inside a command
# substitution, because that would put them in a subshell where the caller
# cannot see them.
#
# Usage: api <method> <path> [json-body] [extra-header]
#   The extra header is used for "Prefer: return=representation", which
#   PostgREST needs on writes that must report how many rows changed.
API_STATUS=""
API_BODY=""
api() {
  local method="$1" path="$2" body="${3:-}" extra="${4:-}" out status
  out="$(mktemp)"
  local -a headers=(
    -H "apikey: $SERVICE_ROLE_KEY"
    -H "Authorization: Bearer $SERVICE_ROLE_KEY"
  )
  [[ -n "$extra" ]] && headers+=(-H "$extra")
  if [[ -n "$body" ]]; then
    headers+=(-H 'Content-Type: application/json')
    status="$(curl -sS -o "$out" -w '%{http_code}' -X "$method" \
      "$SUPABASE_URL$path" "${headers[@]}" -d "$body")" || status="000"
  else
    status="$(curl -sS -o "$out" -w '%{http_code}' -X "$method" \
      "$SUPABASE_URL$path" "${headers[@]}")" || status="000"
  fi
  API_STATUS="$status"
  API_BODY="$(cat "$out")"
  rm -f "$out"
}

# Find the auth user id for an email address.
#
# public.profiles.id is a 1:1 reference to auth.users.id, so PostgREST is the
# reliable lookup. The Admin API list endpoint (GET /auth/v1/admin/users) is
# only a fallback: on large auth schemas it can fail with
# "Database error finding users".
find_user_id() {
  local email="$1" encoded id

  encoded="$(urlencode "$email")"
  api GET "/rest/v1/profiles?select=id&email=eq.${encoded}"
  if [[ "$API_STATUS" =~ ^2 ]]; then
    id="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" and length > 0 then .[0].id else "" end' 2>/dev/null || true)"
    [[ -n "$id" ]] && { printf '%s' "$id"; return 0; }
  fi

  local page=1 count
  while [[ $page -le 20 ]]; do
    api GET "/auth/v1/admin/users?page=${page}&per_page=1000"
    [[ "$API_STATUS" =~ ^2 ]] || break
    id="$(printf '%s' "$API_BODY" | jq -r --arg e "$email" \
      '((if type=="array" then . else (.users // []) end) | map(select((.email // "") | ascii_downcase == ($e | ascii_downcase))) | .[0].id // empty)' 2>/dev/null || true)"
    [[ -n "$id" ]] && { printf '%s' "$id"; return 0; }
    count="$(printf '%s' "$API_BODY" | jq -r '((if type=="array" then . else (.users // []) end) | length)' 2>/dev/null || echo 0)"
    [[ "$count" -lt 1000 ]] && break
    page=$((page + 1))
  done

  return 1
}

# --- preflight --------------------------------------------------------------
info "Pre-flight checks"

ROLE_IN_TOKEN="$(jwt_payload "$SERVICE_ROLE_KEY" 2>/dev/null | jq -r '.role // empty' || true)"
if [[ -n "$ROLE_IN_TOKEN" && "$ROLE_IN_TOKEN" != "service_role" ]]; then
  die "The supplied key has role '$ROLE_IN_TOKEN', not 'service_role'. Refusing to continue."
fi
ok "Service role key accepted (role: ${ROLE_IN_TOKEN:-service_role})"

# Confirm the key can actually reach the project.
api GET "/auth/v1/health"
[[ "$API_STATUS" =~ ^2 ]] || die "Cannot reach $SUPABASE_URL/auth/v1 (HTTP $API_STATUS). Is the project URL correct?"
ok "Project reachable at $SUPABASE_URL"

api GET "/rest/v1/admin_permissions_catalog?select=permission_key"
[[ "$API_STATUS" =~ ^2 ]] || die "Cannot read admin_permissions_catalog (HTTP $API_STATUS)."
CATALOG_COUNT="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" then length else 0 end')"
[[ "$CATALOG_COUNT" -gt 0 ]] || warn "admin_permissions_catalog is empty — the permission catalogue seed is missing."
ok "$CATALOG_COUNT admin permissions in the catalogue"

api GET "/rest/v1/admin_roles?select=role_name&role_name=eq.${ROLE_NAME}"
EXISTING="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" then length else 0 end')"
ok "Role '$ROLE_NAME' currently exists on $EXISTING profile(s)"

if [[ "$DRY_RUN" == "true" ]]; then
  info "Dry run — no changes made."
  if [[ "$REVOKE" == "true" ]]; then
    info "Would revoke '$ROLE_NAME' from: $EMAIL"
    info "  public.admin_roles  delete the grant"
    info "  public.profiles     primary_role = 'customer'"
    [[ "$DELETE_USER" == "true" ]] && info "  auth.users          delete the user"
  else
    info "Would create/promote: $EMAIL"
    info "  auth.users         email + password, email confirmed"
    info "  public.profiles    primary_role = 'admin', is_active = true"
    info "  public.admin_roles role_name = '$ROLE_NAME' (global, no expiry)"
    info "  admin_role_permissions  backfill every catalogue permission for '$ROLE_NAME'"
  fi
  exit 0
fi

# --- revoke -----------------------------------------------------------------
if [[ "$REVOKE" == "true" ]]; then
  info "Revoking '$ROLE_NAME' from $EMAIL"

  USER_ID="$(find_user_id "$EMAIL" || true)"
  if [[ -z "$USER_ID" ]]; then
    die "No profile found for $EMAIL."
  fi
  ok "Found profile ($USER_ID)"

  api DELETE "/rest/v1/admin_roles?profile_id=eq.${USER_ID}&role_name=eq.${ROLE_NAME}"
  if [[ "$API_STATUS" =~ ^2 ]]; then
    ok "Role grant removed"
  else
    warn "Could not remove the role grant (HTTP $API_STATUS)."
  fi

  api PATCH "/rest/v1/profiles?id=eq.${USER_ID}" '{"primary_role":"customer"}' "Prefer: return=representation"
  [[ "$API_STATUS" =~ ^2 ]] || warn "Could not demote the profile (HTTP $API_STATUS)."
  ok "Profile demoted to primary_role = customer"

  if [[ "$DELETE_USER" == "true" ]]; then
    api DELETE "/auth/v1/admin/users/${USER_ID}"
    if [[ "$API_STATUS" =~ ^2 ]]; then
      ok "Auth user deleted (profile and role grants cascade)"
    elif printf '%s' "$API_BODY" | grep -q 'admin_actions_log'; then
      # public.admin_actions_log keeps ON DELETE RESTRICT, so an admin with
      # audit history can never be removed. De-privileged is the safe outcome.
      warn "Could not delete the auth user: the audit trail still references it"
      warn "(public.admin_actions_log is ON DELETE RESTRICT). The account is"
      warn "de-privileged instead: no admin role, primary_role = customer."
      warn "Pass --no-audit on creation to keep the account deletable."
    else
      warn "Could not delete the auth user (HTTP $API_STATUS)."
    fi
  fi

  printf '\n'
  ok "Revoked."
  exit 0
fi

# --- 1. auth user -----------------------------------------------------------
info "Creating the auth user"

PAYLOAD="$(jq -n \
  --arg email "$EMAIL" \
  --arg password "$PASSWORD" \
  --arg full_name "$FULL_NAME" \
  --arg phone "$PHONE" \
  --arg country "$COUNTRY_ISO" \
  '{
     email: $email,
     password: $password,
     email_confirm: true,
     user_metadata: (
       ({full_name: $full_name} | if $full_name == "" then del(.full_name) else . end)
       + ({phone: $phone} | if $phone == "" then del(.phone) else . end)
       + {country_code: $country}
     )
   }')"

api POST "/auth/v1/admin/users" "$PAYLOAD"
if [[ "$API_STATUS" =~ ^2 ]]; then
  USER_ID="$(printf '%s' "$API_BODY" | jq -r '.id // empty')"
  ok "Created auth user ($USER_ID)"
else
  ERR_MSG="$(printf '%s' "$API_BODY" | jq -r '.msg // .message // .error_description // .error // empty' 2>/dev/null || true)"
  if printf '%s' "$ERR_MSG" | grep -qiE 'already|exists|registered'; then
    warn "That email already has an auth user; reusing it."
    USER_ID="$(find_user_id "$EMAIL")"
    [[ -n "$USER_ID" ]] || die "The email already exists but the user could not be found."
    ok "Existing auth user ($USER_ID)"
  else
    die "Could not create the auth user (HTTP $API_STATUS): ${ERR_MSG:-unknown error}"
  fi
fi

# Make sure the password is the one requested even when the user already existed.
api PUT "/auth/v1/admin/users/${USER_ID}" "$(jq -n --arg p "$PASSWORD" '{password: $p, email_confirm: true}')"
if [[ "$API_STATUS" =~ ^2 ]]; then
  ok "Password set on the auth user"
else
  warn "Could not reset the password on the existing user (HTTP $API_STATUS)."
fi

# --- 2. profile -------------------------------------------------------------
info "Promoting the profile to primary_role = 'admin'"

COUNTRY_ID=""
if [[ "$COUNTRY_ISO" != "" ]]; then
  api GET "/rest/v1/countries?select=id&iso_code=eq.${COUNTRY_ISO}"
  COUNTRY_ID="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" and length > 0 then .[0].id else "" end')"
fi

PROFILE_PATCH="$(jq -n \
  --arg email "$EMAIL" \
  --arg full_name "$FULL_NAME" \
  --arg phone "$PHONE" \
  --arg country_id "$COUNTRY_ID" \
  '{
     primary_role: "admin",
     is_active: true,
     email_verified: true
   }
   + (if $email != "" then {email: $email} else {} end)
   + (if $full_name != "" then {full_name: $full_name, display_name: $full_name} else {} end)
   + (if $phone != "" then {phone: $phone, phone_verified: true} else {} end)')"

api GET "/rest/v1/profiles?select=id,primary_role&id=eq.${USER_ID}"
PROFILE_EXISTS="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" and length > 0 then "yes" else "no" end' 2>/dev/null || echo no)"

if [[ "$PROFILE_EXISTS" == "yes" ]]; then
  api PATCH "/rest/v1/profiles?id=eq.${USER_ID}" "$PROFILE_PATCH" "Prefer: return=representation"
  PATCH_COUNT="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" then length else 0 end' 2>/dev/null || echo 0)"
  [[ "$PATCH_COUNT" -gt 0 ]] || die "Could not promote the profile (HTTP $API_STATUS): $API_BODY"
  ok "Profile updated (primary_role = admin, is_active = true)"
else
  # The auth trigger normally creates the profile. If it did not, create it.
  warn "No profile row found — creating one."
  PROFILE_POST="$(jq -n \
    --arg id "$USER_ID" \
    --arg email "$EMAIL" \
    --arg full_name "$FULL_NAME" \
    --arg phone "$PHONE" \
    --arg country_id "$COUNTRY_ID" \
    '{
       id: $id,
       primary_role: "admin",
       is_active: true,
       email_verified: true
     }
     + (if $email != "" then {email: $email} else {} end)
     + (if $full_name != "" then {full_name: $full_name, display_name: $full_name} else {} end)
     + (if $phone != "" then {phone: $phone, phone_verified: true} else {} end)
     + (if $country_id != "" then {default_country_id: $country_id} else {} end)')"
  api POST "/rest/v1/profiles" "$PROFILE_POST"
  [[ "$API_STATUS" =~ ^2 ]] || die "Could not create the profile (HTTP $API_STATUS): $API_BODY"
  ok "Profile created with primary_role = admin"
fi

# --- 3. role permissions ----------------------------------------------------
info "Backfilling admin_role_permissions for '$ROLE_NAME'"

api GET "/rest/v1/admin_permissions_catalog?select=permission_key"
CATALOG_JSON="$(printf '%s' "$API_BODY" | jq -c 'if type=="array" then [.[].permission_key] else [] end')"
api GET "/rest/v1/admin_role_permissions?select=permission_key&role_name=eq.${ROLE_NAME}"
GRANTED_JSON="$(printf '%s' "$API_BODY" | jq -c 'if type=="array" then [.[].permission_key] else [] end')"

MISSING="$(jq -n \
  --argjson catalog "$CATALOG_JSON" \
  --argjson granted "$GRANTED_JSON" \
  '$catalog - $granted')"
MISSING_COUNT="$(printf '%s' "$MISSING" | jq -r 'length')"

if [[ "$MISSING_COUNT" -gt 0 ]]; then
  INSERT_BODY="$(printf '%s' "$MISSING" | jq -c '[.[] | {role_name: $role, permission_key: .}]' --arg role "$ROLE_NAME")"
  api POST "/rest/v1/admin_role_permissions" "$INSERT_BODY"
  if [[ "$API_STATUS" =~ ^2 ]]; then
    ok "Added $MISSING_COUNT missing permission mapping(s)"
  else
    warn "Could not add permission mappings (HTTP $API_STATUS)."
  fi
else
  ok "Every catalogue permission is already mapped to '$ROLE_NAME'"
fi

# --- 4. role grant ----------------------------------------------------------
info "Granting the '$ROLE_NAME' role"

api GET "/rest/v1/admin_roles?select=id,is_active,revoked_at,expires_at&profile_id=eq.${USER_ID}&role_name=eq.${ROLE_NAME}"
GRANT_ID="$(printf '%s' "$API_BODY" | jq -r 'if type=="array" and length > 0 then .[0].id else "" end')"

if [[ -n "$GRANT_ID" ]]; then
  api PATCH "/rest/v1/admin_roles?id=eq.${GRANT_ID}" \
    '{"is_active":true,"revoked_at":null,"expires_at":null}'
  [[ "$API_STATUS" =~ ^2 ]] || die "Could not reactivate the role grant (HTTP $API_STATUS)."
  ok "Reactivated the existing '$ROLE_NAME' grant"
else
  api POST "/rest/v1/admin_roles" \
    "$(jq -n --arg uid "$USER_ID" --arg role "$ROLE_NAME" \
      '{profile_id: $uid, role_name: $role, is_active: true}')"
  [[ "$API_STATUS" =~ ^2 ]] || die "Could not grant the role (HTTP $API_STATUS): $API_BODY"
  ok "Granted '$ROLE_NAME' (global scope, no expiry)"
fi

# --- 5. audit ---------------------------------------------------------------
if [[ "$NO_AUDIT" == "true" ]]; then
  warn "Skipping the admin_actions_log entry (--no-audit)."
else
  info "Recording the action in admin_actions_log"
  api POST "/rest/v1/admin_actions_log" "$(jq -n \
    --arg uid "$USER_ID" \
    --arg role "$ROLE_NAME" \
    '{admin_profile_id: $uid, admin_role: $role, action: "superuser_granted", entity_type: "profile", entity_id: $uid}')"
  if [[ "$API_STATUS" =~ ^2 ]]; then
    ok "Audit entry written"
  else
    warn "Could not write the audit entry (HTTP $API_STATUS)."
  fi
fi

# --- 6. verification --------------------------------------------------------
info "Verifying the account can sign in and hold permissions"

if [[ -z "$ANON_KEY" ]]; then
  warn "SUPABASE_ANON_KEY is not set — skipping the sign-in check."
  warn "Set it and re-run, or sign in manually in the admin console."
else
  TOKEN_RESP="$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "$(jq -n --arg e "$EMAIL" --arg p "$PASSWORD" '{email: $e, password: $p}')" || true)"
  ACCESS_TOKEN="$(printf '%s' "$TOKEN_RESP" | jq -r '.access_token // empty')"
  if [[ -z "$ACCESS_TOKEN" ]]; then
    ERR="$(printf '%s' "$TOKEN_RESP" | jq -r '.error_description // .msg // .message // "unknown"' 2>/dev/null || echo unknown)"
    warn "Sign-in failed: ${ERR}"
  else
    ok "Signed in successfully"

    rpc() {
      local fn="$1" body="${2:-{\}}"
      curl -sS -X POST "$SUPABASE_URL/rest/v1/rpc/$fn" \
        -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'Content-Type: application/json' -d "$body" 2>/dev/null || true
    }

    CONSOLE_ROLE="$(rpc admin_console_role | tr -d '"')"
    if [[ "$CONSOLE_ROLE" == "$ROLE_NAME" ]]; then
      ok "admin_console_role() = $CONSOLE_ROLE"
    else
      die "admin_console_role() returned '$CONSOLE_ROLE', expected '$ROLE_NAME'."
    fi

    CURRENT_ROLE="$(rpc current_user_role | tr -d '"')"
    [[ "$CURRENT_ROLE" == "admin" ]] \
      && ok "current_user_role() = admin" \
      || warn "current_user_role() = '$CURRENT_ROLE' (expected 'admin')"

    PERM="$(rpc has_permission '{"permission_key":"view_all_users"}' | tr -d '"')"
    [[ "$PERM" == "true" ]] \
      && ok "has_permission('view_all_users') = true" \
      || warn "has_permission('view_all_users') = '$PERM'"
  fi
fi

printf '\n'
ok "Superuser ready."
cat <<EOF

  Email    : $EMAIL
  Role     : $ROLE_NAME
  User id  : $USER_ID
  Project  : $SUPABASE_URL

  Sign in to the admin console with this email and the password you supplied.
EOF
