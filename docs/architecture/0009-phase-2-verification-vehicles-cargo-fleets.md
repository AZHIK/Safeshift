# Design 0009 — Phase 2: Verification, Vehicles, Cargo and Fleets

- **Status:** Implemented (Phase 2)
- **Date:** 2026-10-21
- **Scope:** Country-aware document verification, dynamic vehicle and cargo catalogues, and fleet operations.
- **Depends on:** [Design 0008](0008-phase-1-multi-country-foundation.md)
- **Migrations:** `0018`–`0036`
- **Verification:** `supabase/scripts/verify-phase-2-schema.sql`

## 1. Overview and scope

Phase 2 adds 22 tables in four domains on top of the Phase 1 geography, identity, RBAC, localization and audit foundation.

| Domain | Tables |
| --- | --- |
| Verification | `document_types`, `driver_documents`, `vehicle_documents`, `verification_requests`, `verification_history`, `document_expiry_reminders`, `verification_checklist_templates` |
| Vehicles | `vehicle_types`, `vehicle_makes`, `vehicle_models`, `vehicles`, `vehicle_equipment_catalog`, `vehicle_equipment` |
| Cargo | `cargo_categories`, `cargo_types`, `cargo_restrictions`, `cargo_packaging_options` |
| Fleet | `fleets`, `fleet_members`, `fleet_vehicles`, `vehicle_assignments`, `fleet_reports` |

Two Phase 1 placeholders are resolved: `drivers.current_vehicle_id` now references `vehicles(id) ON DELETE SET NULL`, and `drivers.current_fleet_id` references `fleets(id) ON DELETE SET NULL`.

### Migration order

The dependency-safe order differs from a simple domain list because `vehicles` needs `fleets`, `vehicle_types`, `vehicle_makes` and `vehicle_models`, and `fleets` must exist before `vehicles.owner_fleet_id`.

| Migration | Contents |
| --- | --- |
| `0018` | `document_types` |
| `0019` | `vehicle_makes`, `vehicle_models` |
| `0020` | `vehicle_types` (adds `vehicle_models.vehicle_type_id` FK) |
| `0021` | `vehicle_equipment_catalog` |
| `0022` | `cargo_categories` |
| `0023` | `cargo_types` |
| `0024` | `cargo_restrictions`, `cargo_packaging_options` |
| `0025` | `fleets` |
| `0026` | `vehicles` |
| `0027` | `vehicle_equipment` |
| `0028` | `fleet_members`, `fleet_vehicles`, `vehicle_assignments`, `fleet_reports` |
| `0029` | `driver_documents` |
| `0030` | `vehicle_documents` |
| `0031` | `verification_requests`, `verification_history`, `verification_checklist_templates` |
| `0032` | `document_expiry_reminders` |
| `0033` | Resolve Phase 1 driver placeholders |
| `0034` | Indexes and partial unique guards |
| `0035` | Permissions catalogue additions, RLS, grants |
| `0036` | Helpers, audit integration, views |

**No Phase 2 enums were created.** Vehicle types, cargo types and document types are dynamic tables so a new market or regulation does not require a migration. Fixed-but-expandable values use `TEXT` plus `CHECK` constraints. The four public enums remain the Phase 1 set: `user_role`, `driver_verification_status`, `driver_risk_tier`, `audit_action`.

## 2. Driver verification workflow

1. The driver uploads a document into `driver_documents` with `file_path` (the Storage bucket arrives in a later phase). `is_current` defaults to true.
2. A new version of an existing document type must first mark the old row `is_current = false` and link it through `superseded_by`. A partial unique index enforces at most one current row per `(driver_id, document_type_id)`.
3. A `verification_requests` row is created for `driver_verification` or `document_renewal`, with a priority, SLA due time and optional reviewer assignment.
4. The verification admin checks the country's active `verification_checklist_templates` row and reviews the documents.
5. On approval/rejection, the workflow updates the request status and document status. RLS allows the driver to edit a document only while it is `pending`; once reviewed, only a reviewer or the service role can change verification fields.
6. The decision is recorded in three places:
   - `verification_history` — operational narrative (submitted, assigned, approved, rejected, expired, reopened).
   - `admin_actions_log` — queryable admin action record for approve/reject.
   - `private.audit_log` — immutable generic audit entry written by the audit trigger.
7. `public.driver_requires_verification(driver_id)` is the server-side gate. It returns true when any required document is missing, expired or not `verified`. It **fails closed**: a country with no active checklist requires verification rather than silently clearing the driver.

Vehicle verification follows the same pattern with `vehicle_documents`, `vehicle_verification`, and `public.vehicle_requires_verification(vehicle_id)`.

## 3. Dynamic vehicle types

`vehicle_types` carries:

- country scope (`NULL` = global, otherwise a country-specific catalogue row),
- payload and volume ranges,
- maximum dimensions,
- wheel count and special-licence flag,
- required equipment codes,
- display order and active flag.

To add a type:

1. Insert a `vehicle_types` row with a durable code (for example `refrigerated_truck`), capacity bounds and `country_id`.
2. Associate applicable `vehicle_models` with `vehicle_type_id`.
3. Add the equipment codes the type requires.
4. Reference the code in `cargo_types.allowed_vehicle_type_codes` / `prohibited_vehicle_type_codes`.
5. Add any new required document to the country checklist.

No enum or mobile release is needed. `vehicles` is the physical asset; it stores registration and capacity, and points at a type, make and model. Ownership is exclusive: `individual`, `fleet`, `business` or `safeshift`, enforced by `vehicles_owner_shape_check`.

## 4. Dynamic cargo types

`cargo_categories` is a self-referencing hierarchy. `cargo_types` is country-aware and carries handling, declared-value and insurance flags plus allow/prohibit lists of vehicle type codes.

To add a cargo type:

1. Insert or reuse a `cargo_categories` row.
2. Insert a `cargo_types` row with a durable code, `country_id` and category.
3. Set `allowed_vehicle_type_codes` (empty means all) and any `prohibited_vehicle_type_codes`.
4. Add restrictions, declared-value/insurance requirements and display order.
5. Optionally add a packaging option if the existing six do not fit.

`public.can_carry_cargo(vehicle_id, cargo_type_id)` is the capability check. It requires an active vehicle, active vehicle type and active cargo type in the same country, rejects prohibited vehicle codes and enforces a non-empty allow-list. It does not check live capacity, route, price or documents; those belong to later job flows.

## 5. Fleet model

A fleet is a legal/operational entity with:

- country and optional primary city,
- trading name, BRELA registration, TIN and contact details,
- optional billing address,
- owner profile,
- optional commission-rate override,
- verification state.

`fleet_members` records driver membership and role history (`owner`, `manager`, `driver`). `fleet_vehicles` records vehicles managed by the fleet. Both use partial unique indexes so a driver can belong to only one active fleet and a vehicle can appear in only one active fleet at a time.

Fleets coexist with individual drivers and vehicles:

- A vehicle can be owned by an individual, a fleet, a business or SafeShift.
- Fleet-owned vehicles set `owner_type = 'fleet'` and `owner_fleet_id`.
- A fleet can also operate an individually owned vehicle through `vehicle_assignments` and `fleet_vehicles`, subject to RLS and business rules.
- `fleets.owner_profile_id` is the accountable owner; `fleet_members.role = 'owner'` is supported as an additional owner signal.

Owner foreign keys on `vehicles` are `ON DELETE RESTRICT`, not `SET NULL`, because the owner-shape check would otherwise be violated by deleting an owner. Deactivate or reassign a vehicle before removing its legal owner.

## 6. Driver–vehicle assignments over time

`vehicle_assignments` is the authoritative time-based relationship:

1. Insert a row with `vehicle_id`, `driver_id`, `assigned_by` and `assigned_at`.
2. To end it, set `unassigned_at`, `unassign_reason` and `is_active = false`.
3. Insert the next assignment.

Partial unique indexes enforce one active assignment per vehicle and one active vehicle per driver. `public.vehicle_current_driver(vehicle_id)` and `public.driver_current_vehicle(driver_id)` resolve the active relationship without relying on the denormalised `drivers.current_vehicle_id` pointer. The pointer is retained for Phase 1 compatibility and is updated by the application when assignments change.

## 7. Cargo restrictions engine

`cargo_restrictions` stores rules that do not fit in the basic allow/prohibit lists:

| `restriction_type` | Meaning |
| --- | --- |
| `cannot_combine` | This cargo cannot share a vehicle with `restricted_with_cargo_type_id`. |
| `requires_certificate` | A named certificate is required (for example hazmat or veterinary). |
| `requires_special_vehicle` | A specific vehicle type/equipment is mandatory. |
| `age_restricted` | Cargo or driver age constraints apply. |
| `prohibited_route` | Route/zone constraints apply. |
| `time_restricted` | Movement is limited to declared hours. |

`restriction_details` is the machine-readable rule payload; `description` is the operator-readable explanation. Phase 2 provides the catalogue and the basic capability helper; combination validation, certificate checks, route checks and live load checks are applied when jobs are created in Phase 4.

## 8. Document expiry reminders

`document_expiry_reminders` stores one scheduled delivery target for exactly one driver or vehicle document, with reminder windows (`30_days`, `14_days`, `7_days`, `1_day`, `expired`), channel and delivery state.

Phase 5 will use `pg_cron` to:

1. Find current documents approaching expiry.
2. Insert reminder rows idempotently for the relevant windows.
3. Invoke the notification provider for push/SMS/email.
4. Record `sent_at`, `delivery_status` and retry failures.

The schema deliberately separates scheduling from delivery so failures are observable and retryable. The seed creates three pending reminders to exercise the queue.

## 9. What happens when a driver document expires

1. The scheduled reminder becomes due and the notification is sent.
2. `public.driver_requires_verification(driver_id)` starts returning true because the current document is expired.
3. The Phase 4 dispatch workflow should set the driver unavailable and stop offering jobs.
4. The driver uploads a replacement. The old row becomes `is_current = false` and is linked via `superseded_by`.
5. The replacement starts as `pending`; a verification request is created.
6. A reviewer approves it. `driver_requires_verification` becomes false once every required document is valid, and dispatch eligibility can be restored.
7. History and audit rows remain intact; nothing is deleted.

The same flow applies to vehicle documents and vehicle dispatch eligibility.

## 10. Multi-country rollout

Tanzania is the launch market, but the model is configuration-driven.

- `document_types`, `vehicle_types` and `cargo_types` have optional `country_id`. `NULL` means global; a country ID means a market-specific row.
- `verification_checklist_templates` is unique per `(country_id, request_type)`.
- `vehicle_makes`, `vehicle_models`, equipment, cargo categories and packaging are global catalogues unless a later country needs an override.
- Requests and helper functions resolve against the subject's `country_id` (and city where admin scope requires it).

To add Kenya after Tanzania:

1. Activate Kenya in Phase 1 and load its cities/service zones.
2. Add Kenya-specific document types (for example NTSA documents) or reuse global ones.
3. Add the Kenya checklist rows for driver, vehicle and business verification.
4. Add Kenya-specific vehicle types and cargo types, keeping the same durable codes where semantics match.
5. Grant country-scoped admin roles. Do not edit or delete Tanzania rules.

A code may exist once globally and once per country. `UNIQUE (country_id, code)` is declared `NULLS NOT DISTINCT` so a global code cannot be duplicated.

## 11. Security, testing and known limitations

### Security

- RLS is enabled on every Phase 2 table.
- Catalogue data is authenticated-read.
- Document and vehicle rows are owner/fleet/reviewer scoped.
- Reminder, verification-history and fleet-report writes are service-role only.
- Every policy uses `(select auth.uid())`.
- Every `SECURITY DEFINER` helper sets `search_path = ''`.
- `anon` has no Phase 2 table privileges.
- Phase 2 permissions are added by migration `0035`, not only by the development seed, so a migration-only production deployment is operable.

### Verification

```bash
supabase db reset                 # applies migrations and both seed files
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-2-schema.sql
```

The script checks the Phase 1 gate, placeholder foreign keys, table inventory, FK validation, RLS/policy coverage, indexes, helpers, views, the no-new-enums rule, seed counts, permissions, audit triggers, RLS hygiene and a controlled document-verification audit update. The final line must read `PHASE 2 SCHEMA VERIFICATION: X PASS, 0 FAIL`.

### Deferred to later phases

- `vehicle_public_view` is deliberately narrow (no registration, chassis, engine or owner data). It currently relies on vehicle RLS, so customer visibility through an active job is added in Phase 4 when jobs exist.
- Storage buckets, signed upload URLs, malware scanning, OCR and document extraction are later platform work.
- `fleet_reports` stores generated-report metadata only; generation and job/earnings metrics arrive after jobs, pricing and payments.
- `active_fleet_roster.active_jobs_count` is a Phase 4 placeholder and is always `0`.
- Route-aware cargo restrictions, certificate validation, co-mingling checks and real-time capacity calculations depend on the Phase 4 job model.
- Expiry scheduling via `pg_cron` and notification delivery are planned for Phase 5.
- `zone_pricing_overrides.pricing_plan_id` still has no FK; it will reference `pricing_plans` in Phase 3.
