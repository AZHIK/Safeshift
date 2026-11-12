#!/usr/bin/env bash
# ============================================================================
# SafeShift — upload the catalogue icons to Supabase Storage
#
# The vehicle categories (public.vehicle_types) and cargo types
# (public.cargo_types) point at an artwork file through their `icon_url`
# column. The files live in this repository under
# supabase/storage/catalog-icons/ and are uploaded to the public
# `catalog-icons` bucket, keeping the same relative path.
#
#   supabase/storage/catalog-icons/vehicle/pickup.svg
#     -> <project>/storage/v1/object/public/catalog-icons/vehicle/pickup.svg
#
# Run this after adding or changing an icon, and after adding a new vehicle
# type or cargo type to the database.
#
# Usage:
#   scripts/upload-catalog-icons.sh
#   scripts/upload-catalog-icons.sh --dry-run
#
# Required environment:
#   SUPABASE_SERVICE_ROLE_KEY   service role / secret key (never the anon key)
#
# Optional environment:
#   SUPABASE_URL                hosted project URL (default https://<ref>.supabase.co)
#
# The service role key is read from the environment, or from
# supabase/functions/.env.local when that file exists. It is never printed.
# ============================================================================

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$REPO_ROOT/supabase/storage/catalog-icons"
BUCKET="catalog-icons"

SUPABASE_URL="${SUPABASE_URL:-}"
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
DRY_RUN="false"

# --- output helpers ---------------------------------------------------------
info() { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[0;32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[0;33m  !!\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<EOF
SafeShift — upload the catalogue icons to Supabase Storage.

Uploads every file under supabase/storage/catalog-icons/ to the public
'$BUCKET' bucket, keeping the relative path, so the icon_url values stored
in public.vehicle_types and public.cargo_types resolve.

Options:
  --dry-run   List the files that would be uploaded and change nothing.
  --help      Show this message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true" ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

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
    esac
  done < "$file"
}
load_env_file "$REPO_ROOT/supabase/functions/.env.local"

[[ -n "$SERVICE_ROLE_KEY" ]] || die "SUPABASE_SERVICE_ROLE_KEY is not set."
[[ "$SERVICE_ROLE_KEY" != replace-* ]] || die "SUPABASE_SERVICE_ROLE_KEY is still a placeholder."

if [[ -z "$SUPABASE_URL" ]]; then
  REF="$(cat "$REPO_ROOT/supabase/.temp/project-ref" 2>/dev/null || true)"
  [[ -n "$REF" ]] && SUPABASE_URL="https://${REF}.supabase.co"
fi
[[ -n "$SUPABASE_URL" ]] || die "SUPABASE_URL is not set. Export it or add it to supabase/functions/.env.local."
SUPABASE_URL="${SUPABASE_URL%/}"

if [[ "$SUPABASE_URL" != *".supabase.co" ]]; then
  warn "Target '$SUPABASE_URL' is not a hosted Supabase project."
  warn "This script is meant for hosted projects. Continue only if that is intended."
fi

[[ -d "$ICON_DIR" ]] || die "icon directory not found: $ICON_DIR"

# --- collect the files ------------------------------------------------------
FILES=()
while IFS= read -r file; do
  FILES+=("$file")
done < <(find "$ICON_DIR" -type f \( -name '*.svg' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort)

[[ ${#FILES[@]} -gt 0 ]] || die "no icon files found under $ICON_DIR"

info "Uploading ${#FILES[@]} icon file(s) to '$BUCKET' at $SUPABASE_URL"

if [[ "$DRY_RUN" == "true" ]]; then
  for file in "${FILES[@]}"; do
    printf '  would upload %s\n' "${file#"$ICON_DIR/"}"
  done
  ok "Dry run — nothing was uploaded."
  exit 0
fi

# --- upload -----------------------------------------------------------------
FAILED=0
for file in "${FILES[@]}"; do
  relative="${file#"$ICON_DIR/"}"
  case "$relative" in
    *.svg)  content_type="image/svg+xml" ;;
    *.png)  content_type="image/png" ;;
    *.jpg|*.jpeg) content_type="image/jpeg" ;;
    *.webp) content_type="image/webp" ;;
    *)      content_type="application/octet-stream" ;;
  esac

  status="$(curl -sS -o /tmp/catalog-icons-response.json -w '%{http_code}' \
    -X POST "$SUPABASE_URL/storage/v1/object/$BUCKET/$relative" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Content-Type: $content_type" \
    -H "x-upsert: true" \
    --data-binary "@$file" || true)"

  case "$status" in
    200|201)
      ok "$relative"
      ;;
    *)
      FAILED=$((FAILED + 1))
      warn "$relative -> HTTP $status"
      [[ -s /tmp/catalog-icons-response.json ]] && cat /tmp/catalog-icons-response.json && printf '\n'
      ;;
  esac
done
rm -f /tmp/catalog-icons-response.json

if [[ "$FAILED" -gt 0 ]]; then
  die "$FAILED file(s) failed to upload."
fi

ok "All icons uploaded."
info "Public base URL: $SUPABASE_URL/storage/v1/object/public/$BUCKET"
