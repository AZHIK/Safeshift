#!/usr/bin/env bash
# ============================================================================
# SafeShift — Phase 8 live integration gate (local Supabase stack)
#
# Exercises the real PostgREST/Auth/Storage APIs with the seeded demo users:
#   customer1@safeshift.local / SafeshiftDev!2026
#   driver1@safeshift.local   / SafeshiftDev!2026
#
# Usage:
#   supabase/scripts/verify-phase-8-integration.sh
#
# This script is intentionally local-only. It never reads or writes production
# credentials and does not call SMS, Maps, FCM, or payment providers.
# ============================================================================

set -euo pipefail

BASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
DEMO_PASSWORD="${SAFESHIFT_DEMO_PASSWORD:-SafeshiftDev!2026}"

pass=0
fail=0

ok() {
  printf 'PASS  %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL  %s\n' "$1"
  fail=$((fail + 1))
}

check_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    ok "$label"
  else
    bad "$label (expected '$expected', got '$actual')"
  fi
}

check_nonempty() {
  local label="$1" value="$2"
  if [[ -n "$value" && "$value" != "null" ]]; then
    ok "$label"
  else
    bad "$label (empty response)"
  fi
}

login() {
  local email="$1"
  curl -fsS -X POST "$BASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" \
    -H 'content-type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$DEMO_PASSWORD\"}"
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "apikey: $ANON_KEY" \
      -H "authorization: Bearer $token" \
      -H 'content-type: application/json' \
      -H 'prefer: return=representation' \
      -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "apikey: $ANON_KEY" \
      -H "authorization: Bearer $token"
  fi
}

echo "== Phase 8 live integration against $BASE_URL =="

printf '\x89PNG\r\n\x1a\n' >/tmp/safeshift-phase8-evidence.png

CUSTOMER_JSON="$(login customer1@safeshift.local)"
DRIVER_JSON="$(login driver1@safeshift.local)"
CUSTOMER_TOKEN="$(jq -r '.access_token' <<<"$CUSTOMER_JSON")"
DRIVER_TOKEN="$(jq -r '.access_token' <<<"$DRIVER_JSON")"
CUSTOMER_ID="$(jq -r '.user.id' <<<"$CUSTOMER_JSON")"
DRIVER_ID="$(jq -r '.user.id' <<<"$DRIVER_JSON")"

check_nonempty 'customer password sign-in returns a JWT' "$CUSTOMER_TOKEN"
check_nonempty 'driver password sign-in returns a JWT' "$DRIVER_TOKEN"
check_eq 'customer token belongs to seeded customer' \
  'c0000000-0000-4000-8000-000000000001' "$CUSTOMER_ID"
check_eq 'driver token belongs to seeded driver' \
  'd0000000-0000-4000-8000-000000000001' "$DRIVER_ID"

# ---------------------------------------------------------------------------
# 1. Quote -> job -> dispatch -> offer
# ---------------------------------------------------------------------------
QUOTE_ID="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/quote_calculate_and_persist \
  "$(jq -nc --arg customer "$CUSTOMER_ID" '{
    p_customer_id: $customer,
    p_pickup_location: "SRID=4326;POINT(39.2750 -6.8150)",
    p_pickup_address: "Integration pickup",
    p_destination_location: "SRID=4326;POINT(39.2500 -6.8000)",
    p_destination_address: "Integration destination",
    p_vehicle_type_id: "22000000-0000-4000-8000-000000000001",
    p_cargo_type_id: "25000000-0000-4000-8000-000000000001",
    p_cargo_weight_kg: 200,
    p_distance_km: 5.4,
    p_duration_min: 18
  }')" | jq -r '.')"
check_nonempty 'quote_calculate_and_persist returns a quote id' "$QUOTE_ID"

JOB_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/jobs?select=id' \
  "$(jq -nc --arg quote "$QUOTE_ID" '{quote_id: $quote}')" | jq -r '.[0].id')"
check_nonempty 'customer can create a job from the quote' "$JOB_ID"

DISPATCH="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/match_dispatch \
  "$(jq -nc --arg job "$JOB_ID" '{
    p_job_id: $job, p_radius_km: 20, p_limit: 5, p_timeout_seconds: 60
  }')")"
check_eq 'match_dispatch creates at least one offer' 'true' \
  "$(jq -r '.count >= 1' <<<"$DISPATCH")"

OFFERS="$(api "$DRIVER_TOKEN" POST /rest/v1/rpc/driver_pending_offers '{}')"
OFFER_ID="$(jq -r --arg job "$JOB_ID" '.[] | select(.job_id == $job) | .offer_id' <<<"$OFFERS" | head -n1)"
check_nonempty 'driver sees the pending offer' "$OFFER_ID"

# ---------------------------------------------------------------------------
# 2. Accept and advance the job through the driver flow
# ---------------------------------------------------------------------------
api "$DRIVER_TOKEN" POST /rest/v1/rpc/accept_job_offer \
  "$(jq -nc --arg offer "$OFFER_ID" '{p_offer_id: $offer}')" >/dev/null
ACTIVE="$(api "$DRIVER_TOKEN" POST /rest/v1/rpc/driver_active_job '{}')"
check_eq 'driver_active_job returns the accepted job' "$JOB_ID" \
  "$(jq -r '.[0].job_id // empty' <<<"$ACTIVE")"

for status in heading_to_pickup arrived loading in_transit; do
  api "$DRIVER_TOKEN" POST /rest/v1/rpc/job_advance_status \
    "$(jq -nc --arg job "$JOB_ID" --arg status "$status" '{
      p_job_id: $job, p_new_status: $status, p_reason: "Phase 8 integration test"
    }')" >/dev/null
done
ok 'driver advanced the job to in_transit'

THREAD_CUSTOMER="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/ensure_job_chat_thread \
  "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job}')" | jq -r '.')"
THREAD_DRIVER="$(api "$DRIVER_TOKEN" POST /rest/v1/rpc/ensure_job_chat_thread \
  "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job}')" | jq -r '.')"
check_eq 'both participants resolve the same chat thread' "$THREAD_CUSTOMER" "$THREAD_DRIVER"

CHAT_PATH="$JOB_ID/integration-chat.png"
curl -fsS -X POST "$BASE_URL/storage/v1/object/chat-attachments/$CHAT_PATH" \
  -H "apikey: $ANON_KEY" \
  -H "authorization: Bearer $CUSTOMER_TOKEN" \
  -H 'content-type: image/png' \
  --data-binary @/tmp/safeshift-phase8-evidence.png >/dev/null
MESSAGE_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/chat_messages?select=id' \
  "$(jq -nc --arg thread "$THREAD_CUSTOMER" --arg user "$CUSTOMER_ID" '{
    thread_id: $thread, sender_profile_id: $user, message_type: "image",
    body: "Integration attachment"
  }')" | jq -r '.[0].id')"
check_nonempty 'chat message insert returns an id' "$MESSAGE_ID"

api "$CUSTOMER_TOKEN" POST /rest/v1/chat_attachments \
  "$(jq -nc --arg message "$MESSAGE_ID" --arg thread "$THREAD_CUSTOMER" \
    --arg path "$CHAT_PATH" '{
      message_id: ($message | tonumber), thread_id: $thread,
      storage_path: $path, file_mime_type: "image/png", file_size_bytes: 8
    }')" >/dev/null
ATTACHMENT_COUNT="$(api "$CUSTOMER_TOKEN" GET \
  "/rest/v1/chat_attachments?thread_id=eq.$THREAD_CUSTOMER&select=id" | jq 'length')"
check_eq 'chat attachment row was stored' '1' "$ATTACHMENT_COUNT"

# ---------------------------------------------------------------------------
# 3. Delivery OTP: customer issues, driver verifies
# ---------------------------------------------------------------------------
DELIVERY_CODE="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/job_issue_delivery_otp \
  "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job}')" | jq -r '.')"
check_eq 'customer issued a 6-digit delivery code' 'true' \
  "$(jq -rn --arg code "$DELIVERY_CODE" '$code | test("^[0-9]{6}$")')"

VERIFIED="$(api "$DRIVER_TOKEN" POST /rest/v1/rpc/job_verify_delivery_otp \
  "$(jq -nc --arg job "$JOB_ID" --arg code "$DELIVERY_CODE" '{
    p_job_id: $job, p_code: $code
  }')")"
check_eq 'driver verified the delivery code' 'true' "$VERIFIED"

api "$DRIVER_TOKEN" POST /rest/v1/rpc/job_advance_status \
  "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job, p_new_status: "completed", p_reason: "Phase 8 integration test"}')" >/dev/null

CUSTOMER_JOB="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/customer_job \
  "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job}')")"
check_eq 'customer_job reports the completed job' 'completed' \
  "$(jq -r '.[0].status // empty' <<<"$CUSTOMER_JOB")"

# ---------------------------------------------------------------------------
# 4. Job evidence upload
# ---------------------------------------------------------------------------
EVIDENCE_PATH="$JOB_ID/integration-evidence.png"
curl -fsS -X POST "$BASE_URL/storage/v1/object/job-evidence/$EVIDENCE_PATH" \
  -H "apikey: $ANON_KEY" \
  -H "authorization: Bearer $CUSTOMER_TOKEN" \
  -H 'content-type: image/png' \
  --data-binary @/tmp/safeshift-phase8-evidence.png >/dev/null
api "$CUSTOMER_TOKEN" POST /rest/v1/job_evidence \
  "$(jq -nc --arg job "$JOB_ID" --arg path "$EVIDENCE_PATH" --arg user "$CUSTOMER_ID" '{
    job_id: $job, evidence_type: "delivery_photo", storage_path: $path,
    file_mime_type: "image/png", file_size_bytes: 8, created_by: $user
  }')" >/dev/null
EVIDENCE_COUNT="$(api "$CUSTOMER_TOKEN" GET \
  "/rest/v1/job_evidence?job_id=eq.$JOB_ID&select=id" | jq 'length')"
check_eq 'job evidence row was stored' '1' "$EVIDENCE_COUNT"

# ---------------------------------------------------------------------------
# 5. Driver read models used by the app tabs
# ---------------------------------------------------------------------------
for rpc in driver_trips driver_documents_list driver_vehicle_info driver_ratings_list; do
  body='{}'
  if [[ "$rpc" == 'driver_trips' || "$rpc" == 'driver_ratings_list' ]]; then
    body='{"p_limit":5}'
  fi
  if api "$DRIVER_TOKEN" POST "/rest/v1/rpc/$rpc" "$body" >/dev/null; then
    ok "driver read model responds: $rpc"
  else
    bad "driver read model responds: $rpc"
  fi
done

if api "$DRIVER_TOKEN" POST /rest/v1/rpc/driver_earnings_summary '{}' \
  | jq -e 'has("today_amount") and has("last_7_days")' >/dev/null; then
  ok 'driver_earnings_summary returns the expected shape'
else
  bad 'driver_earnings_summary returns the expected shape'
fi

rm -f /tmp/safeshift-phase8-evidence.png

echo
printf 'Phase 8 live integration: %d passed, %d failed\n' "$pass" "$fail"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
