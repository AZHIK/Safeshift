# SafeShift logistics scenarios and UX plan

Status: draft, 2026-11-20. This plan lists the situations a courier and
moving app has to handle, from booking to settlement. For each one it records
what SafeShift does today and what to build. It complements
[production-readiness-plan.md](production-readiness-plan.md), which covers
release gates; this plan covers product behaviour.

Status legend:

- **Handled**: verified in code in this pass.
- **Fixed now**: fixed in migrations 0154/0155 and the app changes that go
  with them.
- **Partial**: some support exists, but the flow has a gap.
- **Missing**: no support found in the apps or migrations.

Priority: **P0** blocks launch or loses money/trust, **P1** is expected by
users of comparable apps, **P2** is polish or scale.

## Guiding UX rules

1. Never leave a customer on a spinner without a reason and a next step.
   Every empty or failed state names the cause and offers an action.
2. The server owns state; the apps only render it. Timers, caps, radius
   and fees live in the database so every client behaves the same.
3. Money moves only with consent the user can see. Show fees before the
   action that incurs them, not on the receipt.
4. A move that one driver cannot finish is reassigned, not cancelled.
5. Every state change reaches the other party within seconds: realtime,
   then push, then polling as fallback.

---

## 1. Booking and quoting

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 1.1 | Quote expires while the customer reads it | Handled: job insert re-quotes once on SQLSTATE 22023 | Show "Price updated" when the re-quote differs by more than 5% instead of silently charging the new price | P1 |
| 1.2 | Cargo not allowed in the chosen vehicle | Handled: `canVehicleCarryCargo` and `_validateLoad` | none | – |
| 1.3 | Load heavier than vehicle capacity | Handled client-side; quote engine checks too | none | – |
| 1.4 | Pickup or drop-off outside the service area | Partial: boundary data exists (0139); app copy not verified | Validate on pin drop and say "We don't serve this area yet" before the vehicle step | P1 |
| 1.5 | Pin lands on the wrong spot (GPS drift, building entrance) | Partial: map picker exists | Add a "pickup notes" field (gate, floor, landmark) shown to the driver | P1 |
| 1.6 | Sender is not the recipient | **Fixed now** (0157): "Who receives it?" on the booking sheet; editable until delivery; the driver sees the recipient's name and phone | none | – |
| 1.7 | Several drop-offs in one move | Partial: `job_stops` tables exist, apps do not use them | Multi-stop booking, ordered stops, per-stop proof | P2 |
| 1.8 | Scheduled move | Handled: dispatch starts 45 minutes before | Remind the customer 1 hour before; let them edit or cancel without a fee until dispatch starts | P1 |
| 1.9 | Recurring move | Partial: scheduler exists (0124); no customer UI found | Expose "repeat weekly" after a completed move | P2 |
| 1.10 | Repeat a past move | Not verified | "Book again" on history items, prefilled route, vehicle and cargo | P1 |
| 1.11 | Price transparency | Partial: breakdown is returned | Show the base, distance and time breakdown, and VAT, before confirming | P1 |

## 2. Matching and dispatch

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 2.1 | No drivers online at all | Handled: explained reason and retry | Offer "Schedule for later" from the empty state | P1 |
| 2.2 | No driver with the chosen vehicle class | **Fixed now**: lists classes that can carry the load and have drivers online; switching is free | none | – |
| 2.3 | Search radius should widen over time | **Fixed now**: the server escalates 5→10→15→20→25 km; previously the app forced 15 km and could shrink round 2 to 10 km | Show progress: "Searching within 10 km…" | P1 |
| 2.4 | Search never ends when pg_cron is down | **Fixed now**: `job_request_dispatch` retires the job after 6 rounds, no charge | none | – |
| 2.5 | Customer taps "Try again" repeatedly | **Fixed now**: rounds less than 15 s apart are ignored, so attempts are not burned | none | – |
| 2.6 | Every offered driver declines | **Fixed now**: the next round starts immediately instead of after the worker's 35 s cadence | none | – |
| 2.7 | Two drivers accept at the same moment | **Fixed now**: consistent job→offer lock order. The old code deadlocked (reproduced); the loser now sees "Another driver accepted this job first" | none | – |
| 2.8 | One driver offered two jobs, accepts both | **Fixed now**: drivers with a live offer are skipped, and accept refuses a busy driver | none | – |
| 2.9 | Offer expires while the driver is deciding | Handled: 45 s expiry and a countdown | Driver app: haptic or sound at 10 s left | P2 |
| 2.10 | Customer closes the app while searching | Handled: resume restores the job, vehicle, cargo and alternatives | none | – |
| 2.11 | Driver found while the customer app is backgrounded | Partial: push service exists; trigger coverage not verified | Push on accepted, arriving, arrived, delivered; test on real devices | **P0** |
| 2.12 | Demand outstrips supply | **Missing** | Show the expected wait, offer schedule-later, and optionally a surge price that drivers can see | P2 |
| 2.13 | Fair offer distribution | Partial: nearest first, then rating | Penalise repeated expiries; avoid sending every offer to the same top driver | P2 |

## 3. Driver en route to pickup

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 3.1 | Driver cancels after accepting | **Fixed now** (0156): `job_driver_release` returns the move to `requested` and re-dispatches immediately without that driver; the customer sees "finding you another driver at the same price" | Driver penalty policy beyond the acceptance rate (product decision) | – |
| 3.2 | Driver accepts but does not move | **Fixed now** (0156): watchdog in `dispatch_tick` releases drivers after 3 min in `accepted`, 10 min without GPS, or max(45 min, 4×ETA) without reaching pickup | Warn the driver before auto-release | P1 |
| 3.3 | Customer cancels after a driver accepts | **Fixed now**: "Cancel move" in tracking until loading starts; fee previewed from the existing policy before confirming | **Decision needed:** with the current policy an ASAP move is charged the moment a driver accepts (see note below) | **P0** |
| 3.4 | Driver cannot find the pickup | Partial: chat and phone exist | One-tap call and share live location; pickup notes from 1.5 | P1 |
| 3.5 | Driver's GPS goes stale | Handled: `driver_location_fresh` flag | Customer copy: "Driver location last updated 3 min ago" rather than a frozen marker | P1 |
| 3.6 | ETA keeps slipping | **Missing** | Recompute the ETA from the live route; notify the customer when it slips more than 10 minutes | P1 |
| 3.7 | Driver switches vehicle mid-job | Handled: assignment validates the vehicle type | none | – |

## 4. At pickup

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 4.1 | Customer not there (no-show) | **Fixed now** (0156): 10 min free wait with countdowns in both apps; after that the driver can report a no-show, recorded as a customer cancellation under the existing policy | Per-minute waiting fee (pricing change, deferred) | P1 |
| 4.2 | Cargo does not match the booking | **Fixed now** (0156): driver refuses at pickup with a reason; the move is cancelled as a customer cancellation and the customer can rebook | Re-quote on the spot instead of cancelling (customer approves new price) | P1 |
| 4.3 | Cargo needs extra hands or loading time | **Missing** | Optional "helpers" add-on at booking; loading-time allowance in pricing | P2 |
| 4.4 | Pickup proof | Handled: evidence upload | Make a pickup photo mandatory before `in_transit` | P1 |
| 4.5 | Cargo is damaged before pickup | Partial: evidence photos | Pickup photo checklist showing the condition, visible to the customer | P1 |

## 5. In transit

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 5.1 | Live tracking | **Fixed now** (0159 + apps): driver broadcasts every ~3 s on a private Realtime channel (RLS: assigned driver sends, customer listens); history stored every 30 s; GPS filtering; marker glides and rotates; camera follows until touched, with Re-centre; route trimmed on the device and re-fetched only off-route (>80 m) or after 5 min; live ETA | Server-side ETA shared by both apps | P2 |
| 5.2 | Share trip with someone | Handled: `create-trip-share-token`; the recipient now gets a link automatically | none | – |
| 5.3 | Emergency | Handled: SOS function | Test the end-to-end SOS alert on devices; show it in admin in real time | **P0** |
| 5.4 | Route deviation or long stop | **Missing** | Server flags deviation beyond X km or a stop over Y min; notify the customer and ops | P1 |
| 5.5 | Customer changes the destination mid-trip | **Missing** | Request change, then re-quote the difference, then the driver accepts, then the route updates | P1 |
| 5.6 | Vehicle breaks down or the driver is in an accident | **Missing** | "Can't continue" flow: SOS or ops ticket, handover to a new driver with the same OTP and evidence trail (reuse 3.1 re-dispatch with a pickup at the current location) | P1 |
| 5.7 | Network drops for driver or customer | Partial: polling fallback; GPS insert fails offline | Queue location points and status changes offline, replay in order | P1 |

## 6. Delivery

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 6.1 | Handover verification | **Fixed now** (0157): when the goods leave the pickup the server texts the recipient the delivery code and a tracking link; "Resend" gives the customer and recipient the same new code; a used code is never re-issued | Needs `safeshift_tracking_base_url` in Vault for the link | – |
| 6.2 | Recipient unavailable | **Missing** | Wait timer as in 4.1. Then the customer chooses: return to sender (re-quoted), leave with a named neighbour (photo plus name), or reattempt later | P1 |
| 6.3 | Recipient refuses the cargo | **Missing** | Driver records refusal with photo; return-to-sender flow; customer notified | P1 |
| 6.4 | Damage or loss discovered at delivery | Partial: disputes exist | Open a dispute from the delivery screen with photos; declared value informs the claim | P1 |
| 6.5 | Customer confirms delivery | Handled | none | – |
| 6.6 | Customer never confirms | Not verified | Auto-complete N hours after OTP-verified delivery | P1 |

## 7. Payment and money

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 7.1 | Real payment methods | **Missing in app**: `mock_payment_methods.dart` drives the picker | Wire the Selcom/Flutterwave initiate and webhook functions that already exist; decide prepay or pay-on-delivery per method | **P0** |
| 7.2 | Mobile-money prompt fails or times out | Not verified | Retry, switch method, or pay cash, without losing the booking | **P0** |
| 7.3 | Cash payment | Partial: method exists | Driver confirms cash received; reconcile the driver's cash balance against payouts | P1 |
| 7.4 | Refund after cancellation or dispute | Partial: server functions exist, no customer UI | Show refund status and timeline in history | P1 |
| 7.5 | Final price differs from the quote (waiting, re-quote, detour) | **Missing** | Itemised adjustments, each approved by the customer in-app before it applies | P1 |
| 7.6 | Tips | Not verified | Optional tip after rating, paid 100% to the driver | P2 |
| 7.7 | Promo codes | Partial: server support | Promo entry on the confirm sheet with live validation | P2 |

## 8. After the move

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 8.1 | Ratings both ways | Handled | Ask for a reason on low ratings; hide that driver from matching with that customer | P2 |
| 8.2 | Receipt | Handled: receipt card | Emailable or PDF receipt with the VAT breakdown for business customers | P1 |
| 8.3 | Disputes | Handled: tables, customer and driver UI | SLA timer and status updates visible to the user | P1 |
| 8.4 | Lost item left in the vehicle | **Missing** | "Contact driver about a lost item" from history for 24 h, masked call | P2 |

## 9. Platform reliability

| # | Scenario | Status | Plan | Pri |
|---|----------|--------|------|-----|
| 9.1 | App killed mid-flow | Handled for customer search and tracking | Verify the same on the driver app for every active status | P1 |
| 9.2 | pg_cron not running | **Fixed now** for search retirement | Alert ops when `dispatch_tick` hasn't run for 2 minutes | P1 |
| 9.3 | Stuck jobs | **Fixed now** (0158): admin "Stuck jobs" page (from Jobs) with per-stage time limits and silent-GPS detection; actions: search again, reassign driver, cancel (no fee) | Auto-alert ops (Slack/SMS) when the queue grows | P1 |
| 9.4 | Duplicate taps or retries | Handled for dispatch and job insert | Audit `job_advance_status` and payment initiate for idempotency keys | P1 |
| 9.5 | Masked phone numbers | Not verified | Proxy numbers so the customer and driver don't exchange personal numbers | P2 |

---

## Open decision: cancellation fee timing

`job_cancel` charges the customer fee when the cancellation happens less
than `free_cancellation_window_minutes` before `scheduled_at`. An ASAP move's
`scheduled_at` is its creation time, so the fee applies as soon as a driver
accepts. Most apps give a short grace period after acceptance (for example
2 minutes). Changing this touches money logic, so it was left as is; the app
now at least shows the fee before the customer confirms.

## Delivery plan

**Phase A (launch blockers, P0).** In this order, because each later item
reuses an earlier one:

1. Driver release and re-dispatch (3.1), then the driver no-progress
   watchdog (3.2) and the admin stuck-jobs view (9.3).
2. Customer cancel after accept with visible fees (3.3).
3. Pickup wait timer, no-show and cargo-mismatch re-quote (4.1, 4.2).
4. Recipient details, recipient OTP and tracking SMS (1.6, 6.1).
5. Real payments and failure recovery (7.1, 7.2).
6. Push notification coverage and SOS device tests (2.11, 5.3).

**Phase B (expected behaviour, P1).** ETA slip alerts, route deviation,
destination change, breakdown handover, recipient unavailable or refusal,
auto-complete, refunds UI, price-change consent, offline queueing, and search
progress copy.

**Phase C (polish and scale, P2).** Multi-stop, recurring UI, surge and
wait estimates, helpers add-on, tips, lost items, masked numbers, and fairer
offer distribution.

Each item ships with a database test in the style used for migration 0155
(real functions against a scratch Postgres, including concurrent sessions for
anything that takes locks), plus an app test for the new state.

## Changes made in this pass

- `supabase/migrations/0154_job_available_vehicle_types.sql`: counts free
  nearby drivers per vehicle class for the "switch vehicle" options.
- `supabase/migrations/0155_dispatch_ordering_fixes.sql`: dispatch core,
  one-offer-per-driver, deadlock-free accept and decline, double-booking
  guard, immediate re-dispatch after a fully declined round, and
  `job_request_dispatch` (server-owned radius, rate limit and attempt cap).
- Customer app: uses `job_request_dispatch`; clearer "no driver found"
  copy; vehicle alternatives, including after a resume.
- Driver app: plain-language accept outcomes (taken by another driver,
  expired, customer cancelled, already on a job).
