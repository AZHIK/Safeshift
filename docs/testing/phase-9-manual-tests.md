# Phase 9 — Manual Test Checklist

Use the local Supabase stack and seeded accounts unless a step says otherwise.
Seeded password: `SafeshiftDev!2026`.

| Account | Email |
| --- | --- |
| Customer | `customer1@safeshift.local` |
| Driver | `driver1@safeshift.local` |
| Super admin | `superadmin@safeshift.local` |
| National ops | `ops.national@safeshift.local` |
| Dar ops | `ops.dar@safeshift.local` |
| Fleet owner | `fleet.owner@safeshift.local` |

## 0. Reset and start

- [ ] `npx --yes supabase db reset`
- [ ] `npx supabase start` (or confirm the stack is already running)
- [ ] `bash scripts/verify-db.sh` → all phases `0 FAIL`
- [ ] `bash supabase/scripts/verify-phase-9-functions.sh` → `0 FAIL`
- [ ] `bash supabase/scripts/verify-phase-9-integration.sh` → `0 FAIL`

## 1. Customer — business and recurring jobs

- [ ] Sign in as `customer1`.
- [ ] Profile → **Business & Recurring Jobs**.
- [ ] Register a business with legal name, registration number, TIN, contact
  email, and phone.
- [ ] Confirm the business appears as **Pending review**.
- [ ] In the admin console, approve the business verification request.
- [ ] Refresh the customer app; confirm the business is **Verified**.
- [ ] Open **Recurring templates** → create a weekly template.
- [ ] Pause and resume the template; confirm the state persists.
- [ ] Confirm generated `scheduled_jobs` appear after the scheduler runs or after
  `select public.generate_recurring_scheduled_jobs(24);` is run as service role.

## 2. Customer — notification preferences

- [ ] Profile → **Notifications**.
- [ ] Toggle push/SMS/email for job updates, payment, promotions, safety alerts,
  chat, and system.
- [ ] Set quiet hours `22:00`–`06:00`.
- [ ] Save, leave the screen, and return; confirm values persist.
- [ ] Set only one quiet-hour field and confirm the database rejects it (pair
  constraint) or the UI prevents saving.

## 3. Customer — disputes with evidence

- [ ] Profile → **Disputes** → **Open dispute**.
- [ ] Select a job, issue type, description, and requested outcome.
- [ ] Attach a photo.
- [ ] Submit; confirm the detail screen opens.
- [ ] Add a message; confirm it appears on the right.
- [ ] In the admin console → **Disputes**, confirm the case, message count, and
  evidence count are visible.
- [ ] Change status/priority and add resolution notes; save.
- [ ] Refresh the customer dispute; confirm the status and notes are visible.

## 4. Customer — support tickets

- [ ] Profile → **Contact Support** → **New ticket**.
- [ ] Choose a category, subject, and message.
- [ ] Submit; confirm the ticket thread opens.
- [ ] Reply from the customer app.
- [ ] In the admin console → **Support**, open the ticket.
- [ ] Reply as staff and add an internal note.
- [ ] Confirm the customer sees the public reply but not the internal note.
- [ ] Resolve and close the ticket; confirm timestamps are set.

## 5. Customer — safety, SOS, trip sharing

- [ ] Profile → **Emergency Contacts** → add a contact with SOS and trip-start
  notifications enabled.
- [ ] Confirm one primary contact can be set and deleting a contact works.
- [ ] Open an active trip and tap **Share Trip**.
- [ ] Confirm a link is copied and the dialog shows a 24-hour expiry.
- [ ] Open the link in a private browser; confirm it shows status, route labels,
  driver first name, vehicle type, and coarse coordinates only.
- [ ] Confirm the link does not show customer name, fare, exact address text, or
  exact live position.
- [ ] Tap **Emergency** / SOS; confirm the confirmation dialog, then confirm the
  alert is created.
- [ ] In the admin console → **Incidents & SOS**, acknowledge and resolve the
  alert.
- [ ] With the `sos_alert` function configured, confirm SMS/push attempts are
  logged and the on-call admin receives a push.

## 6. Customer — account, privacy, ratings

- [ ] Profile → **Account Settings**; edit name and display name; save.
- [ ] Change email/phone; confirm re-verification is required.
- [ ] Profile → **Terms & Privacy**; request a data export.
- [ ] Request account deletion; confirm the warning and request row.
- [ ] In the admin console → **Data requests**, move the request through
  identity verification and completion.
- [ ] Profile → **Ratings & Reviews**; submit a rating for a completed job and
  confirm it appears in the list.

## 7. Driver — onboarding and go-online gate

- [ ] Create a new driver auth user and profile in Supabase (or use a test user
  with no `drivers` row).
- [ ] Sign in; confirm the router opens **Driver verification**.
- [ ] Complete identity, licence, vehicle, and insurance fields.
- [ ] Upload national ID, licence, vehicle registration, and insurance photos.
- [ ] Submit; confirm the app returns home with a pending verification banner.
- [ ] Try to go online; confirm the toggle is locked and the dialog explains the
  verification requirement.
- [ ] In the admin console → **Verification queue**, approve the driver and
  vehicle requests.
- [ ] Refresh the driver app; confirm the banner clears and going online works.
- [ ] Reject a request with a reason and confirm the driver sees the rejection
  path and can re-upload documents.

## 8. Driver — settings, disputes, support, safety

- [ ] Profile → **Verification status**; confirm the current state and links.
- [ ] Profile → **Account Settings**; edit profile and privacy request.
- [ ] Profile → **Notifications**; save a preference.
- [ ] Profile → **Emergency Contacts**; add a contact.
- [ ] Profile → **Disputes**; open a dispute against a driver job with a photo.
- [ ] Profile → **Contact Support**; create and reply to a ticket.
- [ ] Start an active trip; use **Share trip** and **SOS** from the in-transit
  sheet.
- [ ] Confirm driver cannot change `verification_status` directly through the
  API (the trust-field trigger must reject it).

## 9. Admin console — authentication and roles

- [ ] Open `http://localhost:3001`; confirm redirect to `/login`.
- [ ] Sign in as `superadmin@safeshift.local`; confirm dashboard loads.
- [ ] Sign in as `fleet.owner@safeshift.local`; confirm only Dashboard, Fleets,
  and Settings are visible.
- [ ] Sign in as a user with no `admin_roles` row; confirm access is denied and
  the session is signed out.
- [ ] Confirm no service-role key is present in browser bundles or network
  requests.

## 10. Admin console — operations

- [ ] Dashboard shows live metrics, recent activity, open SOS, and verification
  queue; open a second tab and change a job/ticket to confirm Realtime refresh.
- [ ] **Verifications**: approve and reject requests; confirm audit rows.
- [ ] **Users**: search by name/phone/email and confirm results.
- [ ] **Drivers**: confirm verification, availability, rating, trips, earnings,
  and risk tier.
- [ ] **Jobs**: filter by status and confirm fare/currency.
- [ ] **Payments**: confirm provider status and references.
- [ ] **Payouts**: confirm batches and driver payout items.
- [ ] **Pricing & tariffs**: confirm regulated tariffs and pricing versions.
- [ ] **Promos**: disable and enable a code.
- [ ] **Analytics**: confirm daily bars, totals, and table rows.
- [ ] **Fleets**: as fleet owner, confirm only own fleet; as admin, confirm all
  fleets, vehicles, drivers, and billing events.
- [ ] **Data requests**: update status to completed and confirm `completed_at`.
- [ ] **Settings**: toggle a feature flag; confirm audit/updated timestamp.
- [ ] **Audit log**: confirm admin actions include verification decisions and
  show actor, role, permission, entity, and IP.
- [ ] Public `/trip/[token]`: open a valid link, then an expired/invalid token;
  confirm the unavailable state.

## 11. Final gates

- [ ] `npx --yes supabase db reset`
- [ ] `bash scripts/verify-db.sh`
- [ ] `bash supabase/scripts/verify-phase-9-functions.sh`
- [ ] `bash supabase/scripts/verify-phase-9-integration.sh`
- [ ] `cd apps/customer-mobile && flutter analyze && flutter test`
- [ ] `cd apps/driver-mobile && flutter analyze && flutter test`
- [ ] `pnpm --filter @safeshift/admin-console lint`
- [ ] `pnpm --filter @safeshift/admin-console build`

## 12. Cannot be completed locally

- Real SMS delivery, Firebase push delivery, Maps tiles, and payment-provider
  callbacks require credentials and real devices.
- Universal-link/app-link association files and Apple associated domains require
  staging domains and signing entitlements.
- Camera/gallery and background-location behavior must be checked on Android and
  iOS hardware.
