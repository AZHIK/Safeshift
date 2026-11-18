# SafeShift production readiness plan

Status: in progress. This plan covers the current working tree, including the
uncommitted courier and configuration work through migration 0140. The assumed
first release includes the customer and driver mobile apps, admin console, trip
sharing page, and Supabase backend. Customer web booking is a separate scope
decision. Payment timing and cash policy require a product decision.

## Release rule

Production readiness means the complete customer-to-driver-to-settlement path
passes against a fresh staging project and on real Android and iOS devices,
with provider callbacks, support operations, rollback procedures, and release
monitoring demonstrated. Passing static analysis alone is insufficient.

## P0 — correctness and security

1. **Trusted quote pricing.** Stop accepting client-supplied distance and
   duration as authoritative in `quote_calculate_and_persist`. Calculate them
   in a trusted Edge Function, or derive and validate them server-side. Retain
   a defensible fallback when Maps is unavailable. Add a database integration
   test that submits a forged near-zero route for distant coordinates and
   proves the quote cannot be underpriced. Review grants on the old and new
   signatures after migration.
2. **Booking and dispatch race handling.** Verify job insertion, parcel photo
   upload, dispatch, offer expiry, re-dispatch, cancellation, and driver
   availability in one fresh database. Check idempotent retries and scheduled
   jobs. Add cases for no drivers, stale GPS, duplicate accept, expired offer,
   cancellation during an offer, and app restart mid-job.
3. **Payment contract.** Decide when payment is due and which methods launch.
   Connect the customer UI to real provider initiation and status polling or
   callbacks. Distinguish cash collection from digital payment; never display
   a mock method as payable. Define refund, failed-charge, driver commission,
   payout, and dispute compensation rules before implementing settlement.
   Reconcile each provider event to exactly one financial transition.
4. **Security review.** Recheck all security-definer RPCs, RLS and Storage
   policies for cross-account reads/writes, role escalation, forged locations,
   private evidence access, and share-token expiry. Exercise these with
   authenticated customer, driver, staff, and anonymous test identities.
5. **Unfinished live paths.** Replace or remove production-accessible mock
   screens and unimplemented repositories. The driver `/trips/:id` route must
   load the requested real trip or show a proper missing state. Confirm every
   visible CTA has a working result.

## P1 — automated release gates

6. Fix the two failing admin country-action tests and align the country form
   contract with its database constraints.
7. Run admin Vitest and Deno check/lint/test in CI. Extend database gates
   through migrations 0132–0140, including the configuration gate and the new
   courier integration tests. Keep the existing Flutter analysis and tests.
8. Pin toolchain versions and repair the root Turbo commands so the same
   `check` command runs locally and in CI. Build signed release variants in a
   controlled pipeline; retain artifacts and failure logs.
9. Add focused client tests for quote errors, dispatch retries, payment
   transitions, push/deep-link routing, background location recovery, and
   offline-to-online synchronization. Avoid tests that merely mirror widgets.

## P1 — staging and provider validation

10. Create an isolated staging Supabase project; apply all migrations from
    scratch, seed configuration only, and run SQL, Edge Function, and mobile
    integration gates. Record exact migration version and test results.
11. Deploy required Edge Functions and configure Maps, SMS, FCM, email,
    payment providers, Vault secrets, cron secrets, and webhook endpoints.
    Test successful, failed, duplicate, delayed, and out-of-order callbacks.
12. Publish Android and iOS association files and entitlements. Test OTP,
    push, links, maps, camera, evidence upload, and driver location while the
    app is foregrounded, backgrounded, killed, and reopened on real devices.
13. Complete a full journey with two real devices: register and verify a
    driver and vehicle, book, quote, offer, accept, pickup, deliver with code
    and proof, pay, review, support, cancel, refund, and pay out. Record each
    failure and rerun the journey after fixes.

## P2 — operations and launch control

14. Configure structured error reporting, alerts, dashboards, audit review,
    payment reconciliation, dead-letter replay, support escalation, backup
    restore drills, and incident ownership. Remove sensitive values from logs.
15. Define production environment ownership, secret rotation, feature flags,
    rollback and migration recovery, store signing, release channels, and
    staged rollout. Update stale README/runbooks after behavior is verified.
16. Review privacy, data retention, consent, location sharing, prohibited
    cargo, insurance/claims copy, and local legal and tax obligations with the
    responsible business and legal owners before public launch.

## Execution sequence and exit criteria

| Step | Deliverable                                                 | Exit gate                                                               |
| ---- | ----------------------------------------------------------- | ----------------------------------------------------------------------- |
| 1    | Trusted pricing migration and client/Edge Function contract | Forged-distance integration test passes; honest quote regression passes |
| 2    | Booking and dispatch corrections                            | Fresh database journey and concurrency cases pass                       |
| 3    | Agreed payment and settlement implementation                | Provider sandbox journey reconciles with wallet/ledger                  |
| 4    | Production UI cleanup                                       | All launch routes and CTAs tested without mock behavior                 |
| 5    | CI and database gates                                       | Clean checkout passes all automated checks                              |
| 6    | Staging deployment and device QA                            | Two-device journey and provider failure cases pass                      |
| 7    | Operations and controlled rollout                           | Runbooks, monitoring, restore, and rollback rehearsed                   |

Work on steps 1, 2, 4, and 5 can begin locally. Steps 3, 6, and 7 depend on
the payment decision, provider credentials, deployment access, and business
sign-off. Each step is complete only after its exit gate passes.

## Progress on this working tree

| Step    | Current state                                                                                                                                                                                                                                                                                                                                                                                               |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | Quote client and Edge Function use server-computed distance; migration 0141 restricts direct RPC execution. Flutter and Deno tests pass. Fresh-database permission and quote tests remain pending because the local Docker daemon is unavailable.                                                                                                                                                           |
| 2       | Courier and dispatch corrections in migration 0140 are present, but no fresh-database journey or concurrency cases have been run because Docker is unavailable. Duplicate accept, expired offer, cancellation during an offer, stale GPS, and app-restart cases remain pending.                                                                                                                             |
| 4       | Driver trip detail now loads by id through `driver_trip_detail` (migration 0142), falling back to a cached copy offline and showing explicit missing/error states. The unreachable mock complete-profile route, the unused onboarding placeholder, unimplemented auth and booking repositories, and the fabricated commission breakdown were removed. Remaining launch-route and CTA checks need device QA. |
| 5       | Admin country-action tests pass, and CI now includes admin and Edge Function tests plus a production schema gate. The repository-wide Prettier gate passes after formatting the existing files. Driver trip-detail tests and a live `driver_trip_detail` integration check were added. The database gate has not been run locally because Docker is unavailable.                                            |
| 3, 6, 7 | Payment timing/policy still pending, but pricing plans can now be created, updated, deactivated, and deleted from the admin console; there is no fallback price. Staging/provider access, real devices, and business sign-off remain pending.                                                                                                                                                               |
