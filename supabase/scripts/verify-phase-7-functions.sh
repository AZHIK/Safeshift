#!/usr/bin/env bash
# Phase 7 Edge Function gate.
#
# Static checks always run. Live checks run only when
# SAFESHIFT_LIVE_FUNCTIONS=1 and the local stack + functions server are up.
#
# Usage:
#   supabase/scripts/verify-phase-7-functions.sh
#   SAFESHIFT_LIVE_FUNCTIONS=1 supabase/scripts/verify-phase-7-functions.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTIONS_DIR="$ROOT_DIR/supabase/functions"
CONFIG_FILE="$ROOT_DIR/supabase/config.toml"
REFERENCE_CONFIG="$FUNCTIONS_DIR/_config.toml"
FUNCTIONS_URL="${FUNCTIONS_URL:-http://127.0.0.1:54321/functions/v1}"

DENO_BIN="${DENO_BIN:-}"
if [[ -z "$DENO_BIN" ]]; then
  if command -v deno >/dev/null 2>&1; then
    DENO_BIN="$(command -v deno)"
  elif [[ -x "$HOME/.deno/bin/deno" ]]; then
    DENO_BIN="$HOME/.deno/bin/deno"
  else
    echo "FAIL: deno is not installed" >&2
    exit 1
  fi
fi

FUNCTIONS=(
  health
  auth-validate
  maps-distance
  maps-geocode
  quote-calculate
  sms-send
  email-send
  push-send
  notification-dispatch
  payment-selcom-initiate
  payment-selcom-webhook
  payment-flutterwave-initiate
  payment-flutterwave-webhook
  payment-refund
  payout-execute
  data-export
  scheduled-daily-metrics
  scheduled-demand-capture
  scheduled-retention
)

pass=0
fail=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$label"
    fail=$((fail + 1))
  fi
}

echo "== Phase 7 Edge Function static checks =="

for fn in "${FUNCTIONS[@]}"; do
  check "function directory: $fn" test -d "$FUNCTIONS_DIR/$fn"
  check "entrypoint: $fn/index.ts" test -f "$FUNCTIONS_DIR/$fn/index.ts"
  check "handler: $fn/handler.ts" test -f "$FUNCTIONS_DIR/$fn/handler.ts"
  check "readme: $fn/README.md" test -f "$FUNCTIONS_DIR/$fn/README.md"
  check "config: $fn verify_jwt" grep -Eq "^\\[functions\\.$fn\\]$" "$CONFIG_FILE"
  check "reference config: $fn" grep -Eq "^\\[functions\\.$fn\\]$" "$REFERENCE_CONFIG"
done

check "shared secret helpers" test -f "$FUNCTIONS_DIR/_shared/vault.ts"
check "shared webhook helpers" test -f "$FUNCTIONS_DIR/_shared/webhooks.ts"
check "shared idempotency helpers" test -f "$FUNCTIONS_DIR/_shared/idempotency.ts"
check "provider retry test" test -f "$FUNCTIONS_DIR/_tests/provider-retry.test.ts"
check "webhook test" test -f "$FUNCTIONS_DIR/_tests/payment-webhook.test.ts"
check "quote test" test -f "$FUNCTIONS_DIR/_tests/quote-calculate.test.ts"
check "notification test" test -f "$FUNCTIONS_DIR/_tests/notification-dispatch.test.ts"
check "maps cache test" test -f "$FUNCTIONS_DIR/_tests/maps-distance.test.ts"
check "scheduled test" test -f "$FUNCTIONS_DIR/_tests/scheduled.test.ts"
check "no committed .env.local" test ! -f "$FUNCTIONS_DIR/.env.local"
check "no real secrets in example env" \
  bash -c "! grep -Eq '(sk_live|pk_live|AKIA[0-9A-Z]{16})' '$FUNCTIONS_DIR/.env.local.example'"

echo
echo "== Deno check, lint, and tests =="
if (cd "$FUNCTIONS_DIR" && "$DENO_BIN" task check); then
  pass=$((pass + 1))
else
  echo "FAIL  deno check"
  fail=$((fail + 1))
fi

if (cd "$FUNCTIONS_DIR" && "$DENO_BIN" task lint); then
  pass=$((pass + 1))
else
  echo "FAIL  deno lint"
  fail=$((fail + 1))
fi

if (cd "$FUNCTIONS_DIR" && "$DENO_BIN" task test); then
  pass=$((pass + 1))
else
  echo "FAIL  deno test"
  fail=$((fail + 1))
fi

if [[ "${SAFESHIFT_LIVE_FUNCTIONS:-0}" == "1" ]]; then
  echo
  echo "== Live checks against $FUNCTIONS_URL =="

  check_live() {
    local label="$1"
    local expected_status="$2"
    local method="$3"
    local path="$4"
    local body="${5:-}"
    local headers_file
    headers_file="$(mktemp)"
    local status
    if [[ -n "$body" ]]; then
      status="$(curl -sS -o /tmp/safeshift-phase7-response.json -D "$headers_file" \
        -w '%{http_code}' -X "$method" "$FUNCTIONS_URL/$path" \
        -H 'content-type: application/json' -d "$body")"
    else
      status="$(curl -sS -o /tmp/safeshift-phase7-response.json -D "$headers_file" \
        -w '%{http_code}' -X "$method" "$FUNCTIONS_URL/$path")"
    fi
    rm -f "$headers_file"
    if [[ "$status" == "$expected_status" ]] && grep -q '"data"' /tmp/safeshift-phase7-response.json; then
      printf 'PASS  live %s (%s)\n' "$label" "$status"
      pass=$((pass + 1))
    else
      printf 'FAIL  live %s (expected %s, got %s): %s\n' \
        "$label" "$expected_status" "$status" \
        "$(head -c 300 /tmp/safeshift-phase7-response.json)"
      fail=$((fail + 1))
    fi
  }

  check_live "health" 200 GET "health"
  check_live "auth-validate without JWT" 401 GET "auth-validate"
  check_live "Selcom webhook invalid signature" 401 POST "payment-selcom-webhook" \
    '{"event_type":"payment.updated","event_id":"gate-invalid","data":{"order_id":"x","status":"success"}}'
  check_live "scheduled-daily-metrics without cron secret" 401 POST "scheduled-daily-metrics" '{}'
  check_live "scheduled-retention without cron secret" 401 POST "scheduled-retention" '{}'
else
  echo
  echo "SKIP  live HTTP checks (set SAFESHIFT_LIVE_FUNCTIONS=1 to enable)"
fi

echo
printf 'Phase 7 function gate: %d passed, %d failed\n' "$pass" "$fail"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
