#!/usr/bin/env bash
# ============================================================================
# SafeShift — regenerate the client credential files from the canonical file.
#
# Source of truth:
#   supabase/functions/.env.local
#
# Generated (all git-ignored):
#   apps/customer-mobile/dart_defines.local.json
#   apps/driver-mobile/dart_defines.local.json
#   apps/customer-mobile/.env.local
#   apps/driver-mobile/.env.local
#   apps/customer-mobile/.env.hosted-test
#   apps/driver-mobile/.env.hosted-test
#   apps/admin-console/.env.local
#
# Only the CLIENT-SAFE section of the canonical file is copied. Server-only
# secrets (the Supabase service role key, the shared gates, and every payment,
# SMS, email and FCM credential) are never written to a file a client app or
# browser build can read.
#
# Usage:
#   scripts/sync-dart-defines.sh          # regenerate
#   scripts/sync-dart-defines.sh --check  # fail if anything is out of date
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$REPO_ROOT/supabase/functions/.env.local"

CHECK_ONLY="false"
[[ "${1:-}" == "--check" ]] && CHECK_ONLY="true"

# Keys that are safe to ship to a client. Everything else in the source file
# is treated as server-only and is never copied.
CLIENT_KEYS=(
  ENV
  SUPABASE_URL
  SUPABASE_ANON_KEY
  GOOGLE_MAPS_API_KEY
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
  FIREBASE_STORAGE_BUCKET
  MOCK_MODE
)

# Keys that must never reach a client bundle. Presence of any of these in a
# generated file is a hard failure.
FORBIDDEN_PATTERNS=(
  SUPABASE_SERVICE_ROLE_KEY
  GOOGLE_MAPS_SERVER_API_KEY
  CRON_SECRET
  INTERNAL_FUNCTION_SECRET
  SELCOM_API_KEY
  SELCOM_API_SECRET
  SELCOM_WEBHOOK_SECRET
  FLUTTERWAVE_SECRET_KEY
  FLUTTERWAVE_WEBHOOK_SECRET
  BEEM_API_KEY
  BEEM_SECRET_KEY
  AFRICASTALKING_API_KEY
  RESEND_API_KEY
  FCM_SERVICE_ACCOUNT_JSON
)

info() { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$1"; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

[[ -f "$SOURCE" ]] || die "Source file not found: $SOURCE"

command -v jq >/dev/null 2>&1 || die "jq is required."

# --- read the client-safe values -------------------------------------------
read_value() {
  local key="$1" line k v
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" == *=* ]] || continue
    k="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
    [[ "$k" == "$key" ]] || continue
    v="${line#*=}"
    v="${v%\"}"; v="${v#\"}"
    v="${v%\'}"; v="${v#\'}"
    printf '%s' "$v"
    return 0
  done < "$SOURCE"
  return 1
}

declare -A VALUES=()
MISSING=()
for key in "${CLIENT_KEYS[@]}"; do
  if value="$(read_value "$key")"; then
    VALUES["$key"]="$value"
  else
    MISSING+=("$key")
  fi
done

# --- sanity checks ---------------------------------------------------------
info "Reading client-safe credentials from supabase/functions/.env.local"

ENV_VALUE="${VALUES[ENV]:-dev}"
if [[ "$ENV_VALUE" != "dev" && "$ENV_VALUE" != "staging" && "$ENV_VALUE" != "prod" ]]; then
  die "ENV must be dev, staging or prod (found '$ENV_VALUE')."
fi

URL="${VALUES[SUPABASE_URL]:-}"
if [[ -n "$URL" && "$ENV_VALUE" == "dev" && "$URL" != *"127.0.0.1"* && "$URL" != *"localhost"* ]]; then
  die "ENV=dev points at the hosted project '$URL'. Use ENV=staging or ENV=prod."
fi
ok "ENV=$ENV_VALUE  SUPABASE_URL=${URL:-<unset>}"

ANON="${VALUES[SUPABASE_ANON_KEY]:-}"
if [[ -n "$ANON" && "$ANON" == "$URL"* ]]; then
  die "SUPABASE_ANON_KEY looks like a URL."
fi
# A service role key always starts with the service_role role claim.
if [[ -n "$ANON" ]]; then
  payload="$(printf '%s' "$ANON" | cut -d. -f2)"
  case $((${#payload} % 4)) in
    2) payload="${payload}==" ;;
    3) payload="${payload}=" ;;
  esac
  role="$(printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r '.role // empty' 2>/dev/null || true)"
  if [[ "$role" == "service_role" || "$role" == "supabase_admin" ]]; then
    die "SUPABASE_ANON_KEY holds a '$role' key. That must never be shipped to a client."
  fi
fi
ok "SUPABASE_ANON_KEY looks like a publishable/anon key"

# The canonical file must not have server-only values in its client section.
CLIENT_SECTION_END="$(grep -n '^# 2\. Server-only' "$SOURCE" | head -1 | cut -d: -f1 || true)"
if [[ -n "$CLIENT_SECTION_END" ]]; then
  client_part="$(sed -n "1,${CLIENT_SECTION_END}p" "$SOURCE")"
  for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if printf '%s' "$client_part" | grep -qE "^${pattern}="; then
      die "'$pattern' is a server-only key but sits in the client-safe section."
    fi
  done
fi
ok "No server-only keys in the client-safe section"

# --- build the generated content -------------------------------------------
json_body="$(jq -n \
  --arg env "${VALUES[ENV]:-dev}" \
  --arg url "${VALUES[SUPABASE_URL]:-}" \
  --arg anon "${VALUES[SUPABASE_ANON_KEY]:-}" \
  --arg maps "${VALUES[GOOGLE_MAPS_API_KEY]:-}" \
  --arg fkey "${VALUES[FIREBASE_API_KEY]:-}" \
  --arg fapp "${VALUES[FIREBASE_APP_ID]:-}" \
  --arg fsid "${VALUES[FIREBASE_MESSAGING_SENDER_ID]:-}" \
  --arg fproj "${VALUES[FIREBASE_PROJECT_ID]:-}" \
  --arg fbucket "${VALUES[FIREBASE_STORAGE_BUCKET]:-}" \
  --arg mock "${VALUES[MOCK_MODE]:-false}" \
  '{
     ENV: $env,
     SUPABASE_URL: $url,
     SUPABASE_ANON_KEY: $anon,
     GOOGLE_MAPS_API_KEY: $maps,
     FIREBASE_API_KEY: $fkey,
     FIREBASE_APP_ID: $fapp,
     FIREBASE_MESSAGING_SENDER_ID: $fsid,
     FIREBASE_PROJECT_ID: $fproj,
     FIREBASE_STORAGE_BUCKET: $fbucket,
     MOCK_MODE: $mock
   }')"

env_body="# Generated by scripts/sync-dart-defines.sh — do not edit by hand.
# Source of truth: supabase/functions/.env.local
#
# Run scripts/sync-dart-defines.sh after changing the source file.
#
# ENV=$ENV_VALUE
ENV=$ENV_VALUE
SUPABASE_URL=$URL
SUPABASE_ANON_KEY=$ANON
GOOGLE_MAPS_API_KEY=${VALUES[GOOGLE_MAPS_API_KEY]:-}
FIREBASE_API_KEY=${VALUES[FIREBASE_API_KEY]:-}
FIREBASE_APP_ID=${VALUES[FIREBASE_APP_ID]:-}
FIREBASE_MESSAGING_SENDER_ID=${VALUES[FIREBASE_MESSAGING_SENDER_ID]:-}
FIREBASE_PROJECT_ID=${VALUES[FIREBASE_PROJECT_ID]:-}
FIREBASE_STORAGE_BUCKET=${VALUES[FIREBASE_STORAGE_BUCKET]:-}
MOCK_MODE=${VALUES[MOCK_MODE]:-false}
"

console_env_body="# Generated by scripts/sync-dart-defines.sh — do not edit by hand.
# Source of truth: supabase/functions/.env.local
#
# Run scripts/sync-dart-defines.sh after changing the source file.
NEXT_PUBLIC_SUPABASE_URL=$URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON
NEXT_PUBLIC_SITE_URL=http://localhost:3001
"

# --- write / check ---------------------------------------------------------
write_file() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  if [[ "$CHECK_ONLY" == "true" ]]; then
    if [[ -f "$path" ]] && diff -q <(printf '%s\n' "$content") "$path" >/dev/null 2>&1; then
      ok "up to date: ${path#$REPO_ROOT/}"
    else
      printf '\033[0;31m  !!\033[0m out of date: %s\n' "${path#$REPO_ROOT/}" >&2
      CHANGED=1
    fi
  else
    printf '%s\n' "$content" > "$path"
    ok "wrote ${path#$REPO_ROOT/}"
  fi
}

CHANGED=0

info "Writing the client credential files"
write_file "$REPO_ROOT/apps/customer-mobile/dart_defines.local.json" "$json_body"
write_file "$REPO_ROOT/apps/driver-mobile/dart_defines.local.json" "$json_body"
write_file "$REPO_ROOT/apps/customer-mobile/.env.local" "$env_body"
write_file "$REPO_ROOT/apps/driver-mobile/.env.local" "$env_body"
write_file "$REPO_ROOT/apps/customer-mobile/.env.hosted-test" "$env_body"
write_file "$REPO_ROOT/apps/driver-mobile/.env.hosted-test" "$env_body"
write_file "$REPO_ROOT/apps/admin-console/.env.local" "$console_env_body"

# --- native Maps key -------------------------------------------------------
# The Google Maps SDK for Android/iOS reads the key from the native project,
# not from a dart-define, so the literal lives in the manifest and the
# AppDelegate. Keep them in sync with the canonical file so a different client
# key only ever has to be changed in one place.
MAPS_KEY="${VALUES[GOOGLE_MAPS_API_KEY]:-}"
NATIVE_DRIFT=0

sync_native_maps_key() {
  local file="$1" current
  [[ -f "$file" ]] || return 0
  [[ -n "$MAPS_KEY" ]] || return 0

  current="$(grep -oE 'AIza[0-9A-Za-z_-]{35}' "$file" | head -1 || true)"
  [[ -n "$current" ]] || return 0
  [[ "$current" == "$MAPS_KEY" ]] && return 0

  if [[ "$CHECK_ONLY" == "true" ]]; then
    printf '\033[0;31m  !!\033[0m out of date (Maps key): %s\n' "${file#$REPO_ROOT/}" >&2
    NATIVE_DRIFT=1
    return 0
  fi

  python3 - "$file" "$MAPS_KEY" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as fh:
    text = fh.read()
new = re.sub(r'AIza[0-9A-Za-z_-]{35}', key, text, count=1)
if new != text:
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(new)
PY
  ok "updated Maps key in ${file#$REPO_ROOT/}"
}

info "Syncing the native Google Maps key"
for app in customer-mobile driver-mobile; do
  sync_native_maps_key "$REPO_ROOT/apps/$app/android/app/src/main/AndroidManifest.xml"
  sync_native_maps_key "$REPO_ROOT/apps/$app/ios/Runner/AppDelegate.swift"
done

# --- final leak check ------------------------------------------------------
info "Checking the generated files for server-only keys"
for app in customer-mobile driver-mobile admin-console; do
  for file in "$REPO_ROOT/apps/$app"/.env.local \
              "$REPO_ROOT/apps/$app"/.env.hosted-test \
              "$REPO_ROOT/apps/$app"/dart_defines.local.json; do
    [[ -f "$file" ]] || continue
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
      if grep -qE "(^|[\"=])${pattern}" "$file" 2>/dev/null; then
        die "Server-only key '$pattern' found in ${file#$REPO_ROOT/}"
      fi
    done
  done
done
ok "No server-only keys in any client file"

if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Not present in the source file (left empty): ${MISSING[*]}"
fi

printf '\n'
if [[ "$CHECK_ONLY" == "true" && ( "$CHANGED" -ne 0 || "$NATIVE_DRIFT" -ne 0 ) ]]; then
  die "Some generated files are out of date. Run scripts/sync-dart-defines.sh."
fi
ok "Client credentials are in sync with supabase/functions/.env.local"
