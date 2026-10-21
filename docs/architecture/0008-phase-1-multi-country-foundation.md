# Design 0008 — Phase 1: Multi-Country Foundation

- **Status:** Implemented (Phase 1)
- **Date:** 2026-10-19
- **Scope:** Geography, identity, administration/RBAC, localization/configuration,
  and the security/audit foundation. ~30 tables plus helper functions, RLS,
  column-level security, seed data and a verification script.
- **Supersedes:** the exploratory schemas in earlier prompts. Migration history
  restarts at `0001`.

Phase 1 is the load-bearing floor of the platform. Every later phase (vehicles,
pricing, jobs, payments, disputes) assumes the objects described here exist and
behave as documented.

---

## 1. Overview of Phase 1 scope

Phase 1 delivers five domains:

| Domain | Tables |
| --- | --- |
| 1. Geography and multi-country | `countries`, `regions`, `cities`, `service_zones`, `neighborhoods`, `addresses`, `zone_pricing_overrides` (7) |
| 2. Identity and users | `profiles`, `user_devices`, `user_sessions`, `customers`, `business_accounts`, `business_members`, `drivers`, `driver_status_history`, `driver_operating_zones`, `driver_service_hours`, `user_referrals`, `saved_addresses` (12) |
| 3. Administration and RBAC | `admin_roles`, `admin_permissions_catalog`, `admin_role_permissions`, `admin_actions_log` (4) |
| 4. Localization and configuration | `currencies`, `exchange_rates`, `languages`, `localization_strings`, `feature_flags` (5) |
| 5. Security and audit | `private.audit_log` (partitioned), `consent_records` (2) |

Plus: four enums, eleven helper/RPC functions, a generic audit trigger, four
column-protection triggers, an auth `handle_new_user` trigger, RLS on every
public table, ~60 indexes, two column-level views, seed data, and a verification
script.

### Migration inventory

| File | Purpose |
| --- | --- |
| `0001_extensions_and_schemas.sql` | `postgis`, `pg_cron`, `pgcrypto`; `private` schema; `set_updated_at()` |
| `0002_enums.sql` | `user_role`, `driver_verification_status`, `driver_risk_tier`, `audit_action` |
| `0003_currencies_languages.sql` | `currencies`, `languages` |
| `0004_countries_regions_cities.sql` | `countries`, `regions`, `cities` + country-sync trigger |
| `0005_service_zones_addresses.sql` | `service_zones`, `neighborhoods`, `addresses`, `zone_pricing_overrides` + address hierarchy trigger |
| `0006_profiles_devices_sessions.sql` | `profiles`, `user_devices`, `user_sessions`; adds `addresses.created_by` FK |
| `0007_customers_business.sql` | `customers`, `business_accounts`, `business_members` + owner-bootstrap trigger |
| `0008_drivers.sql` | `drivers`, `driver_status_history`, `driver_operating_zones`, `driver_service_hours` + status-history trigger |
| `0009_referrals_saved_addresses.sql` | `user_referrals`, `saved_addresses` |
| `0010_admin_rbac.sql` | `admin_roles`, `admin_permissions_catalog`, `admin_role_permissions`, `admin_actions_log` |
| `0011_exchange_localization_flags.sql` | `exchange_rates`, `localization_strings`, `feature_flags` |
| `0012_audit_consent.sql` | `private.audit_log` (24 monthly partitions + default), `consent_records`, `ensure_audit_log_partitions()`, `updated_at` trigger rollout |
| `0013_auth_trigger.sql` | `handle_new_user()` and the `auth.users` trigger |
| `0014_helpers.sql` | identity/RBAC helpers, JWT claims hook, `record_consent`, `deactivate_user`, generic audit trigger, column-protection triggers, public driver projection |
| `0015_rls_policies.sql` | RLS enabled + policies for all public tables; privileges |
| `0016_indexes.sql` | access-path, partial and GIST indexes |
| `0017_column_security_views.sql` | `driver_public_profile`, `get_audit_log()`, `audit_log_view` |

> **Note on migration count:** the task's numbering guide (0001–0017) is
> implemented in full. An earlier checklist mentioned "14 files (0001–0014)";
> that line is superseded by the explicit step-by-step instructions, which place
> RLS in 0015, indexes in 0016 and views in 0017.

### Non-negotiables honoured

- No hardcoded country, currency, language, timezone or regulator anywhere in
  schema, functions or triggers — all resolved from tables.
- Money is `numeric(14,2)` / `numeric(12,2)`; never floating point.
- Every `SECURITY DEFINER` function sets `search_path = ''`.
- Every RLS policy uses `(select auth.uid())`, never bare `auth.uid()`.
- The service-role key is never referenced in code; server-only writes have no
  client policy at all.
- No Phase 2+ tables (no vehicles, fleets, pricing plans, jobs, payments).

---

## 2. The multi-country architecture

Geography is a four-level tree, all data-driven:

```
countries ──< regions ──< cities ──< service_zones
                              └──< neighborhoods
profiles.default_country_id ──> countries
drivers.country_id ──> countries
feature_flags.{country_id, city_id} ──> countries/cities
```

Key rules:

- `countries.is_active` gates a market. Inactive countries exist in the schema
  but are not operable.
- `cities.country_id` is denormalised for query performance and **kept in sync
  by trigger** (`public.sync_city_country`), which rejects a city whose country
  disagrees with its region.
- Nothing about a country is special-cased. Regulatory frameworks
  (`LATRA`, `NTSA`, `UNRA`, …) are data. Payment providers, document
  requirements and KYC policy live in `countries.config`.
- Currency and language are per-country defaults, with per-profile overrides.

### Activating a new market is data entry

The seed ships with Tanzania active and Kenya/Uganda inactive. To activate
Kenya, an operator inserts/updates rows — no code, no migration:

```sql
update public.countries set is_active = true, launched_at = now() where iso_code = 'KE';
insert into public.regions (country_id, name, code, is_active) values (...);
insert into public.cities  (region_id, country_id, name, timezone, is_active, launched_at) values (...);
insert into public.service_zones (city_id, name, zone_type, boundary, centroid) values (...);
insert into public.neighborhoods (city_id, name, centroid) values (...);
insert into public.feature_flags (flag_key, country_id, is_enabled, rollout_percentage) values (...);
```

`country_id` on new cities is validated against the region automatically.

---

## 3. The identity model

`public.profiles` is the canonical human record, 1:1 with `auth.users`
(`on delete cascade`). It carries exactly one `primary_role`:

| `primary_role` | Specialisation table | What it represents |
| --- | --- | --- |
| `customer` | `customers` | Consumer booking moves/deliveries |
| `driver` | `drivers` | Verified transporter |
| `business` | `business_accounts` + `business_members` | Corporate account member (owner/admin/booker/viewer) |
| `admin` | `admin_roles` | Platform staff with scoped permissions |
| `fleet_owner` | `fleets` (Phase 2) | Owns multiple vehicles/drivers |

Relationships:

```
auth.users 1──1 profiles
profiles 1──0..1 customers
profiles 1──0..1 drivers
profiles 1──* business_members >── business_accounts
profiles 1──* admin_roles
profiles 1──* user_devices
profiles 1──* user_sessions
profiles 1──* saved_addresses
profiles 1──* consent_records
```

Design decisions:

- **Role is not client-writable.** `handle_new_user` always creates a
  `customer`; elevated roles are granted server-side (service role) or via
  `admin_roles`. A trigger (`private.protect_profile_privileged_fields`) and
  column-level `UPDATE` grants enforce this.
- **Contact requirement.** A profile must have a phone or an email
  (`profiles_contact_present_check`), matching the OTP-first onboarding model.
- **Business authority is a separate axis** from `primary_role`: a user whose
  primary role is `business` may be an owner in one account and a viewer in
  another.

---

## 4. The RBAC model

RBAC is capability-based, not role-string-based:

```
admin_roles(profile, role_name, country_id?, city_id?, expires_at?)
        │ role_name
        ▼
admin_role_permissions(role_name, permission_key) ──> admin_permissions_catalog(permission_key)
```

Six roles ship in Phase 1: `super_admin`, `operations_admin`,
`verification_admin`, `support_agent`, `finance_admin`, `analyst`, mapped to 27
permissions.

### Permission evaluation

`public.has_permission(permission_key text)` returns true when the caller has an
active, unexpired, unrevoked admin grant whose role maps to that permission, and
whose country scope matches the caller's country (a `NULL` country applies
globally). A second form, `has_permission(permission_key text, city_id uuid)`,
also enforces city scope.

Because `has_permission` is `SECURITY DEFINER`, it is safe to call inside RLS
policies without recursing through the RLS of `admin_roles`.

### Worked example — verify_driver

```sql
-- An operator holding a verification grant:
select public.has_permission('verify_driver');   -- true
select public.has_permission('process_payout');  -- false (finance only)

-- Reading drivers is gated on view_all_drivers, which
-- verification_admin has and a customer does not:
select count(*) from public.drivers;   -- 3 for verification_admin, 0 for a customer
```

Every administrative action that changes state should be mirrored into
`admin_actions_log` (service role write), carrying the `permission_used`.

---

## 5. RLS strategy and custom claims

RLS is enabled on **every** public table; policies are default-deny. Three
patterns are used:

1. **Reference data** (`countries`, `regions`, `cities`, `currencies`,
   `languages`, `neighborhoods`, `admin_permissions_catalog`,
   `admin_role_permissions`): `SELECT` to `authenticated`, no client writes.
2. **Permission-gated writes** (`service_zones`, `zone_pricing_overrides`,
   `exchange_rates`, `localization_strings`, `feature_flags`, `admin_roles`):
   policy checks `has_permission(...)`.
3. **Owner-scoped rows** (`profiles`, `user_devices`, `user_sessions`,
   `customers`, `drivers`, `saved_addresses`, `consent_records`, referral and
   driver-operating tables): row ownership compared to `(select auth.uid())`.
   Business and admin tables use `SECURITY DEFINER` membership helpers to avoid
   recursive RLS.

Server-only tables (`user_sessions` inserts, `driver_status_history`,
`admin_actions_log`, `consent_records` mutations, `private.audit_log`) have **no
client write policy**; the service role bypasses RLS and is the only writer.

Performance: policies use `(select auth.uid())` (and `(select
public.has_permission(...))`) so the planner evaluates them once per statement.

### Custom claims

`public.custom_access_token_hook(jsonb)` is configured in `supabase/config.toml`:

```toml
[auth.hook.custom_access_token]
enabled = true
uri = "pg-functions://postgres/public/custom_access_token_hook"
```

It injects `user_role` and `country_id` into every access token, so mobile/web
clients can route and render without an extra round-trip, and so country-scoped
RBAC has a stable reference. The hook is granted only to `supabase_auth_admin`.

Example enriched claims:

```json
{
  "sub": "…",
  "role": "authenticated",
  "user_role": "admin",
  "country_id": "33333333-0000-4000-8000-000000000001"
}
```

---

## 6. Consent recording model (PDPC compliance)

`public.consent_records` is an **immutable** ledger. Each row records:

- `profile_id`, `consent_type` (`terms_of_service`, `privacy_policy`,
  `marketing_email`, `marketing_sms`, `data_processing`)
- `consent_version` (e.g. `2026-10-v1`) — the document version the user saw
- `granted` plus `granted_at`/`revoked_at`
- `ip_address` and `user_agent` captured at the moment of decision

Rules enforced in the schema:

- A check constraint guarantees granted rows carry `granted_at` and no
  `revoked_at`, and revoked rows carry `revoked_at`.
- Clients have **no** `UPDATE` or `DELETE` policy, and those privileges are
  revoked outright. Consent is append-only; a change of mind is a new row.
- Clients record consent through `public.record_consent(...)`, which captures
  request IP/user-agent and writes an audit entry (`consent_granted` /
  `consent_revoked`). A profile may only record its own consent unless the
  caller holds `view_consent`.

This is the PDPC data-processing foundation: the controller can prove what a
user consented to, under which document version, from which address, and when.

---

## 7. Audit logging model

Two complementary trails:

**`private.audit_log`** — generic, append-only, partitioned monthly:

- `PRIMARY KEY (id, created_at)`, `PARTITION BY RANGE (created_at)`.
- 24 monthly partitions created from the current month, plus a safety default
  partition. `private.ensure_audit_log_partitions(n)` rolls them forward and is
  intended to run monthly under `pg_cron`.
- `private.audit_trigger()` is attached to 26 sensitive tables and records
  `actor_id`, `actor_role`, the `audit_action`, table name, row id, `old_value`
  / `new_value`, request IP, user agent and session id.
- The table is completely inaccessible to `anon`/`authenticated`. Reads go
  through `public.audit_log_view`, which returns rows only when the caller has
  `view_audit`.

**`public.admin_actions_log`** — the queryable, semantic admin trail
(`approved_driver`, `adjusted_price`, `refunded_payment`, …) with
`permission_used`, `old_value`/`new_value`, IP and user agent. Written by the
service role from Edge Functions.

**`public.driver_status_history`** — a domain-specific trail of
`verification_status`, `risk_tier` and `is_available` transitions, written
automatically by trigger with the acting `changed_by`.

Retention: `audit_log` partitions can be detached and archived individually;
nothing in Phase 1 deletes audit rows.

---

## 8. Column-level security views and why they exist

RLS controls *which rows* a caller sees; it cannot hide individual columns.
Two views close that gap:

- **`public.driver_public_profile`** (`security_invoker = true`, read-only):
  exposes `id`, `full_name`, `display_name`, `avatar_url`, `rating`,
  `total_trips`, `verification_status`, `home_city_id`, `current_vehicle_id`.
  It never exposes phone, email, licence number or exact coordinates. The data
  comes from `public.get_public_driver_profile()`, a whitelisting `SECURITY
  DEFINER` function, so the projection is safe by construction. In Phase 1 the
  view is usable for a user's own driver row and for admins; Phase 4 adds the
  "customer on an active job" row-visibility policy that makes it useful to
  customers.

- **`public.audit_log_view`** (`security_invoker = true`): projects
  `private.audit_log` but elevates no privileges itself. The privileged read and
  the `WHERE (select public.has_permission('view_audit'))` gate live in the
  `SECURITY DEFINER` function `public.get_audit_log(limit, entity_type, entity_id)`
  (empty `search_path`). Without the permission the view returns zero rows, and
  the `private` schema remains unreachable directly. `security_barrier` prevents
  predicate leakage. Both public views therefore follow the same pattern — a
  `security_invoker` view over a permission-checked `SECURITY DEFINER` function —
  which also avoids the Supabase `security_definer_view` lint finding.

  Callers can use either the view (`select * from public.audit_log_view`, all
  rows, as before) or the function directly with an optional row cap and filters
  (`select * from public.get_audit_log(50, 'drivers', null)`). A `NULL` limit,
  which is the function default, returns every row.

Sensitive columns on base tables are further protected by triggers and
column-level grants (see §5 and §4): `profiles.primary_role`, driver trust
fields, customer aggregates and business credit fields.

---

## 9. How to add a new city in Tanzania

No schema change, no deployment:

```sql
-- 1. Find the region (create it if the region is new).
select id from public.regions where name = 'Arusha Region';

-- 2. Insert the city (country_id must match the region's country).
insert into public.cities (region_id, country_id, name, timezone, latitude, longitude, is_active, launched_at, config)
values (
  (select id from public.regions where name = 'Arusha Region'),
  (select country_id from public.regions where name = 'Arusha Region'),
  'Arusha', 'Africa/Dar_es_Salaam', -3.3869, 36.6830, true, now(),
  '{"currency": "TZS"}'::jsonb
);

-- 3. Draw service zones.
insert into public.service_zones (city_id, name, zone_type, boundary, centroid)
values ((select id from public.cities where name = 'Arusha'), 'Central', 'operating_area',
        ST_GeogFromText('SRID=4326;POLYGON((...))'), ST_GeogFromText('SRID=4326;POINT(36.683 -3.387)'));

-- 4. Add neighborhoods.
insert into public.neighborhoods (city_id, service_zone_id, name, centroid) values (...);

-- 5. Turn on city-scoped feature flags.
insert into public.feature_flags (flag_key, country_id, city_id, is_enabled, rollout_percentage)
values ('mobile_money_checkout', (select country_id from public.cities where name='Arusha'),
        (select id from public.cities where name='Arusha'), true, 100);
```

Because the city trigger enforces that `country_id` matches the region, step 2
cannot create an inconsistent city.

---

## 10. How to add a new country (step by step)

1. **Currency & language.** Ensure they exist:
   `insert into currencies ...; insert into languages ...;`
2. **Country.** `insert into countries (iso_code, name, default_currency_id,
   default_timezone, default_language_id, regulatory_framework,
   tax_registration_required, is_active, config) values (…, false, …);`
   Start inactive.
3. **Regions.** One or more `insert into regions ...`.
4. **Cities.** `insert into cities (...)` — `country_id` must equal the region's
   country (validated by trigger).
5. **Zones & neighborhoods.** `insert into service_zones ...` (boundary +
   centroid required) and `insert into neighborhoods ...`.
6. **Localization.** Add `localization_strings` rows for the country's
   languages.
7. **Feature flags / config.** Add country-scoped `feature_flags` and any
   payment/KYC config in `countries.config`.
8. **Compliance.** Complete the local data-protection registration (e.g. PDPC
   in Tanzania) before collecting production data; set
   `countries.tax_registration_required` accordingly.
9. **Activate.** `update countries set is_active = true, launched_at = now()`
   and activate the first city.

Steps 1–9 are pure data. No migration, function or policy changes are required,
which is the whole point of the multi-country foundation.

---

## 11. Known limitations and what comes in Phases 2–6

**Intentional placeholders (nullable columns awaiting their Phase FK):**

| Column | Target | Added in |
| --- | --- | --- |
| `zone_pricing_overrides.pricing_plan_id` | `pricing_plans` | Phase 3 |
| `customers.preferred_payment_method_id` | `payment_methods` | Phase 5 |
| `drivers.current_vehicle_id` | `vehicles` | Phase 2 |
| `drivers.current_fleet_id` | `fleets` | Phase 2 |

**Deferred behaviour:**

- `drivers` is not yet readable by customers on an active job — the policy
  contains an explicit `or false` placeholder for Phase 4.
- `user_sessions` is an audit/revocation ledger only; Supabase Auth owns
  sessions.
- City-scoped RBAC (`has_permission(text, uuid)`) requires server code to pass
  the city it is acting on; client RLS policies use the country-wide form.
- `private.audit_log` partition rolling is a function, not yet wired to
  `pg_cron`; a monthly schedule should be added in operations.
- Seed `auth.identities` rows may be skipped on local Postgres due to
  permissions; create interactive test accounts through the Auth Admin API.

**Coming later:**

- **Phase 2** — vehicles, fleets, documents, vehicle verification.
- **Phase 3** — pricing plans, tariffs (incl. LATRA-regulated tariffs),
  `zone_pricing_overrides.pricing_plan_id` FK.
- **Phase 4** — jobs, matching, job evidence, driver visibility on active jobs.
- **Phase 5** — payments, mobile-money providers, payment methods, payouts.
- **Phase 6** — disputes, protection/claims, analytics.

---

## 12. How to run the verification script

The schema is defined by `supabase/migrations/`; the local database is rebuilt
from scratch and then verified.

```bash
# 1. Rebuild the local database and apply migrations + seed.
supabase db reset

# 2. Run the verification script against the local database.
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
     -f supabase/scripts/verify-phase-1-schema.sql
```

The script prints one row per check (extensions, all 30 tables, enums and their
exact values, FK validity, RLS coverage, policy coverage, `private` isolation,
audit partitioning, every required index, every helper function,
`custom_access_token_hook`, the auth trigger, the column-level views, seed
counts, multi-country proof and the "no Phase 2+ tables" guard), then a summary
line:

```
PHASE 1 SCHEMA VERIFICATION: 143 PASS, 0 FAIL
```

Any failures are listed again at the end for fast triage. The run must end with
`0 FAIL`.

> If your project does not allow `create extension pg_cron` from a migration,
> enable it from the Supabase dashboard first; migration 0001 uses
> `create extension if not exists` and is safe to re-run.
