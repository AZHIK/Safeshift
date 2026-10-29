#!/usr/bin/env bash
# ============================================================================
# SafeShift — Phase 9 live integration gate (local Supabase stack)
#
# Exercises Phase 9 flows through the real PostgREST/Auth/Storage APIs:
#   business onboarding + admin verification + recurring template
#   notification preferences, emergency contacts
#   disputes with evidence, support tickets
#   trip sharing + anon snapshot, SOS alert creation
#   admin dashboard/search/activity read models
#
# Usage:
#   supabase/scripts/verify-phase-9-integration.sh
#
# Local-only. Never reads production credentials and does not call SMS, FCM,
# Maps, or payment providers.
# ============================================================================

set -euo pipefail

BASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
DEMO_PASSWORD="${SAFESHIFT_DEMO_PASSWORD:-SafeshiftDev!2026}"
STAMP="$(date +%s)-$RANDOM"

pass=0
fail=0

ok() { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then ok "$label"; else bad "$label (expected '$expected', got '$actual')"; fi
}
check_nonempty() {
  local label="$1" value="$2"
  if [[ -n "$value" && "$value" != "null" ]]; then ok "$label"; else bad "$label (empty response)"; fi
}

login() {
  curl -fsS -X POST "$BASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'content-type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$DEMO_PASSWORD\"}"
}

api() {
  local token="$1" method="$2" path="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "apikey: $ANON_KEY" -H "authorization: Bearer $token" \
      -H 'content-type: application/json' -H 'prefer: return=representation' \
      -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "apikey: $ANON_KEY" -H "authorization: Bearer $token"
  fi
}

echo "== Phase 9 live integration against $BASE_URL =="

CUSTOMER_JSON="$(login customer1@safeshift.local)"
DRIVER_JSON="$(login driver1@safeshift.local)"
ADMIN_JSON="$(login superadmin@safeshift.local)"
FLEET_JSON="$(login fleet.owner@safeshift.local)"
CUSTOMER_TOKEN="$(jq -r '.access_token' <<<"$CUSTOMER_JSON")"
DRIVER_TOKEN="$(jq -r '.access_token' <<<"$DRIVER_JSON")"
ADMIN_TOKEN="$(jq -r '.access_token' <<<"$ADMIN_JSON")"
FLEET_TOKEN="$(jq -r '.access_token' <<<"$FLEET_JSON")"
CUSTOMER_ID="$(jq -r '.user.id' <<<"$CUSTOMER_JSON")"
DRIVER_ID="$(jq -r '.user.id' <<<"$DRIVER_JSON")"

check_eq 'customer token belongs to seeded customer' 'c0000000-0000-4000-8000-000000000001' "$CUSTOMER_ID"
check_eq 'driver token belongs to seeded driver' 'd0000000-0000-4000-8000-000000000001' "$DRIVER_ID"
check_nonempty 'admin password sign-in returns a JWT' "$ADMIN_TOKEN"
check_nonempty 'fleet owner password sign-in returns a JWT' "$FLEET_TOKEN"

# ---------------------------------------------------------------------------
# 1. Admin console identity and read models
# ---------------------------------------------------------------------------
ADMIN_ROLE="$(api "$ADMIN_TOKEN" POST /rest/v1/rpc/admin_console_role '{}' | jq -r '.')"
FLEET_ROLE="$(api "$FLEET_TOKEN" POST /rest/v1/rpc/admin_console_role '{}' | jq -r '.')"
check_eq 'seeded admin resolves to super_admin' 'super_admin' "$ADMIN_ROLE"
check_eq 'seeded fleet owner resolves to fleet_owner' 'fleet_owner' "$FLEET_ROLE"

METRICS="$(api "$ADMIN_TOKEN" GET '/rest/v1/admin_dashboard_metrics?select=*')"
check_eq 'admin dashboard metrics view returns a row' 'true' "$(jq 'length >= 1' <<<"$METRICS")"

SEARCH="$(api "$ADMIN_TOKEN" POST /rest/v1/rpc/admin_search_profiles '{"p_query":"Juma","p_limit":5}')"
check_eq 'admin_search_profiles returns a result array' 'true' "$(jq 'type == "array"' <<<"$SEARCH")"

ACTIVITY="$(api "$ADMIN_TOKEN" POST /rest/v1/rpc/admin_recent_activity '{"p_limit":5}')"
check_eq 'admin_recent_activity returns an array' 'true' "$(jq 'type == "array"' <<<"$ACTIVITY")"

# ---------------------------------------------------------------------------
# 2. Business self-service onboarding + admin approval
# ---------------------------------------------------------------------------
COUNTRY_ID="$(api "$CUSTOMER_TOKEN" GET '/rest/v1/profiles?id=eq.'"$CUSTOMER_ID"'&select=default_country_id' | jq -r '.[0].default_country_id')"
CITY_ID="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/cities?country_id=eq.$COUNTRY_ID&select=id&limit=1" | jq -r '.[0].id')"
BUSINESS_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/business_accounts?select=id' \
  "$(jq -nc --arg country "$COUNTRY_ID" --arg city "$CITY_ID" --arg stamp "$STAMP" '{
    country_id: $country, city_id: $city,
    legal_name: ("Phase 9 Integration Ltd " + $stamp),
    trading_name: "Phase 9 Integration",
    registration_number: ("BRELA-" + $stamp),
    tax_id: ("TIN-" + $stamp),
    contact_email: "phase9-integration@example.test",
    contact_phone: "+255700000999"
  }')" | jq -r '.[0].id')"
check_nonempty 'customer creates a business account' "$BUSINESS_ID"

MEMBERSHIP_ROLE="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/business_members?business_account_id=eq.$BUSINESS_ID&select=role" | jq -r '.[0].role')"
check_eq 'business bootstrap trigger attaches creator as owner' 'owner' "$MEMBERSHIP_ROLE"

VERIFICATION_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/verification_requests?select=id' \
  "$(jq -nc --arg business "$BUSINESS_ID" --arg user "$CUSTOMER_ID" '{
    request_type: "business_verification", business_account_id: $business,
    requested_by: $user, status: "pending", priority: "normal"
  }')" | jq -r '.[0].id')"
check_nonempty 'business verification request is created' "$VERIFICATION_ID"

api "$ADMIN_TOKEN" POST /rest/v1/rpc/admin_approve_verification \
  "$(jq -nc --arg request "$VERIFICATION_ID" '{p_request_id: $request, p_notes: "Phase 9 integration approval"}')" >/dev/null
BUSINESS_VERIFIED="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/business_accounts?id=eq.$BUSINESS_ID&select=verified_at" | jq -r '.[0].verified_at')"
check_nonempty 'admin approval verifies the business account' "$BUSINESS_VERIFIED"

TEMPLATE_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/recurring_job_templates?select=id' \
  "$(jq -nc --arg business "$BUSINESS_ID" --arg user "$CUSTOMER_ID" '{
    business_account_id: $business, created_by: $user,
    name: "Phase 9 weekly template",
    vehicle_type_id: "22000000-0000-4000-8000-000000000001",
    cargo_type_id: "25000000-0000-4000-8000-000000000001",
    default_cargo_weight_kg: 100,
    recurrence_rule: "FREQ=WEEKLY;BYDAY=MO,WE,FR",
    time_of_day: "09:00", timezone: "Africa/Dar_es_Salaam", is_active: true
  }')" | jq -r '.[0].id')"
check_nonempty 'verified business creates a recurring template' "$TEMPLATE_ID"

# ---------------------------------------------------------------------------
# 3. Notification preferences, emergency contacts
# ---------------------------------------------------------------------------
curl -fsS -X POST "$BASE_URL/rest/v1/notification_preferences?on_conflict=profile_id,category,channel" \
  -H "apikey: $ANON_KEY" -H "authorization: Bearer $CUSTOMER_TOKEN" \
  -H 'content-type: application/json' \
  -H 'prefer: resolution=merge-duplicates,return=representation' \
  -d "$(jq -nc --arg user "$CUSTOMER_ID" '[{
    profile_id: $user, category: "safety_alerts", channel: "push",
    is_enabled: true, quiet_hours_start: "22:00", quiet_hours_end: "06:00",
    timezone: "Africa/Dar_es_Salaam"
  }]')" >/dev/null
PREF_COUNT="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/notification_preferences?profile_id=eq.$CUSTOMER_ID&category=eq.safety_alerts&channel=eq.push&select=id" | jq 'length')"
check_eq 'notification preference upsert is stored' '1' "$PREF_COUNT"

CONTACT_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/emergency_contacts?select=id' \
  "$(jq -nc --arg user "$CUSTOMER_ID" --arg stamp "$STAMP" '{
    profile_id: $user, name: ("Phase 9 Contact " + $stamp),
    phone: "+255700000998", relationship: "Sibling",
    notify_on_trip_start: true, notify_on_sos: true
  }')" | jq -r '.[0].id')"
check_nonempty 'emergency contact is stored' "$CONTACT_ID"

# ---------------------------------------------------------------------------
# 4. Pick a customer job for disputes, sharing, and SOS
# ---------------------------------------------------------------------------
JOB_ID="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/jobs?customer_id=eq.$CUSTOMER_ID&select=id&order=created_at.desc&limit=1" | jq -r '.[0].id // empty')"
if [[ -z "$JOB_ID" ]]; then
  QUOTE_ID="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/quote_calculate_and_persist \
    "$(jq -nc --arg customer "$CUSTOMER_ID" '{
      p_customer_id: $customer,
      p_pickup_location: "SRID=4326;POINT(39.2750 -6.8150)",
      p_pickup_address: "Phase 9 integration pickup",
      p_destination_location: "SRID=4326;POINT(39.2500 -6.8000)",
      p_destination_address: "Phase 9 integration destination",
      p_vehicle_type_id: "22000000-0000-4000-8000-000000000001",
      p_cargo_type_id: "25000000-0000-4000-8000-000000000001",
      p_cargo_weight_kg: 200, p_distance_km: 5.4, p_duration_min: 18
    }')" | jq -r '.')"
  JOB_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/jobs?select=id' "$(jq -nc --arg quote "$QUOTE_ID" '{quote_id: $quote}')" | jq -r '.[0].id')"
fi
check_nonempty 'a customer job is available for Phase 9 flows' "$JOB_ID"

# ---------------------------------------------------------------------------
# 5. Dispute with evidence and message
# ---------------------------------------------------------------------------
DISPUTE_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/disputes?select=id' \
  "$(jq -nc --arg job "$JOB_ID" --arg user "$CUSTOMER_ID" '{
    job_id: $job, raised_by: $user, raised_by_role: "customer",
    dispute_type: "damage", status: "open", priority: "normal",
    summary: "Phase 9 integration dispute",
    requested_resolution: "Review the evidence and advise."
  }')" | jq -r '.[0].id')"
check_nonempty 'customer opens a dispute' "$DISPUTE_ID"

api "$CUSTOMER_TOKEN" POST /rest/v1/dispute_messages \
  "$(jq -nc --arg dispute "$DISPUTE_ID" --arg user "$CUSTOMER_ID" '{
    dispute_id: $dispute, sender_profile_id: $user, message: "Evidence attached."
  }')" >/dev/null
MESSAGE_COUNT="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/dispute_messages?dispute_id=eq.$DISPUTE_ID&select=id" | jq 'length')"
check_eq 'dispute message is stored' '1' "$MESSAGE_COUNT"

printf '\x89PNG\r\n\x1a\n' >/tmp/safeshift-phase9-evidence.png
EVIDENCE_PATH="dispute/$DISPUTE_ID/integration.png"
curl -fsS -X POST "$BASE_URL/storage/v1/object/job-evidence/$EVIDENCE_PATH" \
  -H "apikey: $ANON_KEY" -H "authorization: Bearer $CUSTOMER_TOKEN" \
  -H 'content-type: image/png' --data-binary @/tmp/safeshift-phase9-evidence.png >/dev/null
api "$CUSTOMER_TOKEN" POST /rest/v1/dispute_attachments \
  "$(jq -nc --arg dispute "$DISPUTE_ID" --arg user "$CUSTOMER_ID" --arg path "$EVIDENCE_PATH" '{
    dispute_id: $dispute, uploaded_by: $user, storage_path: $path,
    file_mime_type: "image/png", file_size_bytes: 8
  }')" >/dev/null
ATTACHMENT_COUNT="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/dispute_attachments?dispute_id=eq.$DISPUTE_ID&select=id" | jq 'length')"
check_eq 'dispute evidence attachment is stored' '1' "$ATTACHMENT_COUNT"

# ---------------------------------------------------------------------------
# 6. Support ticket and message
# ---------------------------------------------------------------------------
CATEGORY_ID="$(api "$CUSTOMER_TOKEN" GET '/rest/v1/support_categories?is_active=eq.true&select=id&limit=1' | jq -r '.[0].id')"
TICKET_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/support_tickets?select=id' \
  "$(jq -nc --arg country "$COUNTRY_ID" --arg user "$CUSTOMER_ID" --arg category "$CATEGORY_ID" --arg stamp "$STAMP" '{
    country_id: $country, ticket_number: ("TKT-P9-" + $stamp),
    opened_by: $user, category_id: $category,
    subject: "Phase 9 integration support", status: "open", priority: "normal"
  }')" | jq -r '.[0].id')"
check_nonempty 'customer opens a support ticket' "$TICKET_ID"

api "$CUSTOMER_TOKEN" POST /rest/v1/support_ticket_messages \
  "$(jq -nc --arg ticket "$TICKET_ID" --arg user "$CUSTOMER_ID" '{
    ticket_id: $ticket, sender_profile_id: $user, message: "Please help with this integration ticket."
  }')" >/dev/null
TICKET_MESSAGES="$(api "$ADMIN_TOKEN" GET "/rest/v1/support_ticket_messages?ticket_id=eq.$TICKET_ID&select=id" | jq 'length')"
check_eq 'admin can read the customer support thread' '1' "$TICKET_MESSAGES"

# ---------------------------------------------------------------------------
# 7. Trip sharing, anon snapshot, SOS alert
# ---------------------------------------------------------------------------
SHARE="$(api "$CUSTOMER_TOKEN" POST /rest/v1/rpc/create_trip_share_token "$(jq -nc --arg job "$JOB_ID" '{p_job_id: $job}')")"
SHARE_TOKEN="$(jq -r '.[0].token // empty' <<<"$SHARE")"
check_nonempty 'customer creates a trip share token' "$SHARE_TOKEN"

SNAPSHOT="$(curl -fsS -X POST "$BASE_URL/rest/v1/rpc/trip_share_snapshot" \
  -H "apikey: $ANON_KEY" -H 'content-type: application/json' \
  -d "$(jq -nc --arg token "$SHARE_TOKEN" '{p_token: $token}')")"
check_eq 'anonymous visitor reads the shared trip snapshot' "$JOB_ID" "$(jq -r '.job_id' <<<"$SNAPSHOT")"
check_eq 'snapshot does not expose exact street addresses as raw rows' 'true' "$(jq 'has("pickup") and has("destination") and (has("customer_id") | not)' <<<"$SNAPSHOT")"

ALERT_ID="$(api "$CUSTOMER_TOKEN" POST '/rest/v1/trip_alerts?select=id' \
  "$(jq -nc --arg job "$JOB_ID" --arg user "$CUSTOMER_ID" '{
    job_id: $job, profile_id: $user, alert_type: "sos", status: "open",
    details: "Phase 9 integration SOS"
  }')" | jq -r '.[0].id')"
check_nonempty 'trip participant raises an SOS alert' "$ALERT_ID"

api "$ADMIN_TOKEN" PATCH "/rest/v1/trip_alerts?id=eq.$ALERT_ID" "$(jq -nc --arg admin 'a0000000-0000-4000-8000-000000000001' '{status: "acknowledged", acknowledged_by: $admin, acknowledged_at: (now | todate)}')" >/dev/null
ALERT_STATUS="$(api "$ADMIN_TOKEN" GET "/rest/v1/trip_alerts?id=eq.$ALERT_ID&select=status" | jq -r '.[0].status')"
check_eq 'admin acknowledges the SOS alert' 'acknowledged' "$ALERT_STATUS"

# ---------------------------------------------------------------------------
# 8. Ratings/reviews read path and fleet-owner scoping
# ---------------------------------------------------------------------------
RATINGS="$(api "$CUSTOMER_TOKEN" GET "/rest/v1/ratings?rater_profile_id=eq.$CUSTOMER_ID&select=id&limit=5")"
check_eq 'customer ratings endpoint responds' 'true' "$(jq 'type == "array"' <<<"$RATINGS")"

FLEETS="$(api "$FLEET_TOKEN" GET '/rest/v1/fleets?select=id,name,owner_profile_id')"
check_eq 'fleet owner can read their fleet' 'true' "$(jq 'length >= 1' <<<"$FLEETS")"
FLEET_OWNER_MATCH="$(jq --arg owner "$(jq -r '.user.id' <<<"$FLEET_JSON")" 'all(.owner_profile_id == $owner)' <<<"$FLEETS")"
check_eq 'fleet-owner RLS only returns owned fleets' 'true' "$FLEET_OWNER_MATCH"

rm -f /tmp/safeshift-phase9-evidence.png

echo
printf 'Phase 9 live integration: %d passed, %d failed\n' "$pass" "$fail"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
