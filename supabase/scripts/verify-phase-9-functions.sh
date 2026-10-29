#!/usr/bin/env bash
# ============================================================================
# SafeShift — Phase 9 Edge Function contract gate
#
# The database gate cannot see the Deno source tree. This companion check
# verifies the two Phase 9 functions are present, wired in config.toml, and
# contain the required authorization and data-access calls.
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTIONS="$ROOT/supabase/functions"
CONFIG="$ROOT/supabase/config.toml"
pass=0
fail=0

ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); }

check_file() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then ok "$label"; else bad "$label (missing $path)"; fi
}

check_grep() {
  local label="$1" pattern="$2" path="$3"
  if grep -Eq "$pattern" "$path"; then ok "$label"; else bad "$label (pattern not found)"; fi
}

check_file 'sos_alert entrypoint exists' "$FUNCTIONS/sos_alert/index.ts"
check_file 'sos_alert handler exists' "$FUNCTIONS/sos_alert/handler.ts"
check_file 'sos_alert README exists' "$FUNCTIONS/sos_alert/README.md"
check_file 'create-trip-share-token entrypoint exists' "$FUNCTIONS/create-trip-share-token/index.ts"
check_file 'create-trip-share-token handler exists' "$FUNCTIONS/create-trip-share-token/handler.ts"
check_file 'create-trip-share-token README exists' "$FUNCTIONS/create-trip-share-token/README.md"

check_grep 'sos_alert authenticates the caller' 'requireUser' "$FUNCTIONS/sos_alert/handler.ts"
check_grep 'sos_alert verifies alert ownership' 'alert.profile_id !== auth.userId' "$FUNCTIONS/sos_alert/handler.ts"
check_grep 'sos_alert notifies emergency contacts' 'emergency_contacts' "$FUNCTIONS/sos_alert/handler.ts"
check_grep 'sos_alert pushes on-call admins' 'admin_roles' "$FUNCTIONS/sos_alert/handler.ts"
check_grep 'sos_alert writes notification_log' 'insertNotificationLog' "$FUNCTIONS/sos_alert/handler.ts"

check_grep 'trip share authenticates the caller' 'requireUser' "$FUNCTIONS/create-trip-share-token/handler.ts"
check_grep 'trip share calls the token RPC' 'create_trip_share_token' "$FUNCTIONS/create-trip-share-token/handler.ts"
check_grep 'trip share returns a public URL' 'share_url' "$FUNCTIONS/create-trip-share-token/handler.ts"

if grep -A2 '^\[functions.sos_alert\]' "$CONFIG" | grep -q 'verify_jwt = false'; then
  ok 'sos_alert is registered in config.toml'
else
  bad 'sos_alert is registered in config.toml'
fi
if grep -A2 '^\[functions.create-trip-share-token\]' "$CONFIG" | grep -q 'verify_jwt = false'; then
  ok 'create-trip-share-token is registered in config.toml'
else
  bad 'create-trip-share-token is registered in config.toml'
fi

if command -v deno >/dev/null 2>&1; then
  if deno check "$FUNCTIONS/sos_alert/index.ts" "$FUNCTIONS/create-trip-share-token/index.ts" >/dev/null 2>&1; then
    ok 'Deno type-check passes for Phase 9 functions'
  else
    bad 'Deno type-check fails for Phase 9 functions'
  fi
else
  printf 'SKIP  Deno is not installed; source contract checks only\n'
fi

printf '\nPHASE 9 FUNCTION VERIFICATION: %d PASS, %d FAIL\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
