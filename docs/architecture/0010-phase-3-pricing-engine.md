# Phase 3 — Pricing Engine

**Status:** implemented and verified
**Migrations:** `0037`–`0051`
**Seed:** `supabase/seed-phase-3.sql`
**Gate:** `supabase/scripts/verify-phase-3-schema.sql` — 150 PASS, 0 FAIL
**Depends on:** Phase 1 (geography, currencies, service zones, profiles, RBAC) and Phase 2 (vehicle types, cargo types, equipment catalogue)

---

## 1. Scope

Phase 3 builds the pricing layer that every later quote will call. It delivers five domains:

| Domain | Tables |
| --- | --- |
| A. Pricing plans and versions | `pricing_plans`, `pricing_plan_versions`, `pricing_plan_zones`, `pricing_plan_vehicle_types` |
| B. Rates and rules | `pricing_plan_base_rates`, `pricing_distance_tiers`, `pricing_weight_tiers`, `pricing_volume_tiers`, `pricing_cargo_surcharges`, `pricing_equipment_surcharges` |
| C. Time and zone modifiers | `pricing_time_multipliers`, `pricing_zone_multipliers`, `zone_pricing_override_resolution` |
| D. Regulated tariffs | `regulated_tariffs`, `regulated_tariff_bands` |
| E. Promotions | `promo_codes`, `promo_redemptions`, `promo_code_eligibility_rules` |

Phase 3 also adds the missing FK from Phase 1's `zone_pricing_overrides.pricing_plan_id` to `pricing_plan_versions(id)`.

What Phase 3 deliberately does **not** contain:

- `quote_history` and job pricing columns — Phase 4.
- `commission_rules`, payouts or driver earnings — Phase 5.
- Real-time demand surge, loyalty tiers or promotion stacking across multiple codes — Phase 4/5.

---

## 2. Plans versus versions: why immutability matters

A **plan** is the stable identity customers and operators recognise:

```text
dar-van-standard  =  Dar es Salaam + Small Van + "Dar es Salaam Small Van Standard"
```

A **version** is the immutable ruleset attached to that identity:

```text
pricing_plan_versions row
  version_number = 2
  effective_from = 2026-07-01
  published_at   = 2026-06-15
  base_fare      = 5,250 TZS
  per_km_rate    = 1,200 TZS
  ...
```

Why this matters:

- A quote must remain explainable months later. Phase 4 stores the exact `pricing_plan_version_id` used, so a historical quote never changes when prices change.
- There is no mutable “current price” column anywhere. “Current” is a query over published versions and their effective windows.
- A published version cannot be edited or deleted by application users. New prices mean a new version, and the previous version is closed by `publish_pricing_plan_version()`.
- The only in-place change allowed on a published version is the atomic supersede transition: setting `effective_to` once and pointing `superseded_by_version_id` at the successor.

The immutability trigger (`private.enforce_published_immutability()`, migration `0047`) covers:

```text
pricing_plan_versions
pricing_plan_zones
pricing_plan_vehicle_types
pricing_plan_base_rates
pricing_distance_tiers
pricing_weight_tiers
pricing_volume_tiers
pricing_cargo_surcharges
pricing_equipment_surcharges
pricing_time_multipliers
pricing_zone_multipliers
```

Draft versions (`published_at IS NULL`) remain editable. Service-role and migration-owner writes bypass the block by design; the gate proves that authenticated admin updates are rejected.

---

## 3. How to add a new pricing plan

A plan is created once. It needs a country, city, vehicle type and a globally unique code. `service_zone_id` is optional: `NULL` means the whole city.

```sql
insert into public.pricing_plans (
  country_id, city_id, service_zone_id, vehicle_type_id,
  code, name, description, display_order
) values (
  '33333333-0000-4000-8000-000000000001',  -- Tanzania
  '55555555-0000-4000-8000-000000000001',  -- Dar es Salaam
  null,                                     -- city-wide
  '22000000-0000-4000-8000-000000000003',  -- Medium Truck
  'dar-mtruck-express', 'Dar Medium Truck Express',
  'Faster medium-truck service.', 35
);
```

Scope coherence is enforced by `public.validate_pricing_plan_scope()`:

- the city must belong to the plan country;
- a zone must belong to the plan city;
- a country-scoped vehicle type must match the plan country.

The database cannot express these as SQL `CHECK` constraints because they cross tables, so a trigger raises `23514`/`23503` instead.

Codes are globally unique (not just unique per city) so back-office tooling and API clients can resolve a plan by code without disambiguation. Use a city/region prefix such as `dar-`, `nbo-` or `kla-`.

---

## 4. How to publish a new version of a plan

The supported workflow is:

```sql
-- 1. Copy the latest version into a new draft.
select public.draft_pricing_plan_version(
  (select id from public.pricing_plans where code = 'dar-van-standard')
) as draft_version_id;

-- 2. Edit the draft freely: rates, tiers, surcharges, multipliers, applicability.
update public.pricing_plan_base_rates
   set base_fare = 5250.00
 where pricing_plan_version_id = :draft_version_id;

update public.pricing_plan_versions
   set effective_from = '2026-07-01 00:00:00+03'
 where id = :draft_version_id;

-- 3. Publish atomically. This sets published_at/published_by, closes the
--    previous overlapping version and links it to the new one.
select public.publish_pricing_plan_version(:draft_version_id);
```

`draft_pricing_plan_version()` copies:

- base rates;
- distance, weight and volume tiers;
- cargo and equipment surcharges;
- time and zone multipliers;
- version-level zone and vehicle-type applicability.

It does not copy the published lifecycle fields. The new row starts with `published_at = NULL`, `effective_to = NULL`, and `effective_from = now()` (adjust it before publishing).

`publish_pricing_plan_version()` validates that base rates exist, then in one transaction:

1. sets `published_at = now()` and `published_by = auth.uid()` (when available);
2. finds the previous published version for the same plan whose effective window overlaps the new version;
3. sets the previous version's `effective_to` to the new version's `effective_from`;
4. sets the previous version's `superseded_by_version_id` to the new version id.

A transaction-local publish context (`safeshift.publish_context`) is what allows step 3/4 through the immutability trigger. The trigger also verifies that **only** the supersede fields changed.

---

## 5. The rate structure

All money columns are `numeric(14,2)`. Every monetary table carries `currency_code char(3)` referencing `currencies.code`. Percentages and multipliers are `numeric(6,4)`. No `float` or `double` exists in Phase 3.

`pricing_plan_base_rates` has exactly one row per version:

| Column | Meaning |
| --- | --- |
| `base_fare` | Fixed pickup/base charge. |
| `per_km_rate` | Fallback distance rate when no distance tier covers a slice. |
| `per_min_rate` | Time charge per minute. |
| `minimum_charge` | Floor applied before zone/time multipliers. |
| `loading_fee` | Loading service fee (informational/line item; not auto-added by `quote_preview`). |
| `unloading_fee` | Unloading service fee (same). |
| `waiting_per_min_rate` | Waiting charge after the free window. |
| `waiting_free_minutes` | Included waiting minutes (default 5). |
| `multi_stop_fee` | Per-extra-stop fee. |
| `vat_rate` | Fraction, e.g. `0.1800` = 18%. |

`quote_preview()` currently has no waiting-minutes or extra-stop parameters, so it returns `waiting_charge = 0` and `multi_stop_charge = 0`. Phase 4's quote engine will pass those inputs.

---

## 6. Distance, weight and volume tiering

**Distance tiers** replace `per_km_rate` for the distance slice they cover. Gaps fall back to the base rate.

```text
0–10 km   at 1,200 TZS/km
10+ km    at 1,000 TZS/km
```

For 15 km the charge is `10 × 1,200 + 5 × 1,000`. If tiers only covered `0–5` and `10+`, the `5–10` gap would be charged at `per_km_rate`.

**Weight tiers** apply one matching band. `flat_fee` adds money; `multiplier` scales the base + distance + time component by `(value − 1)`.

**Volume tiers** work identically using cubic metres.

Overlap is rejected by triggers:

- distance ranges within one version;
- weight ranges within one version;
- volume ranges within one version;
- regulated tariff bands of the same `band_type` within one tariff.

A band with `max = NULL` means “and above”, so `0–10` and `10–NULL` are adjacent, not overlapping.

---

## 7. Cargo and equipment surcharges

`pricing_cargo_surcharges` is unique per `(version, cargo_type)`. Supported types:

| Type | Behaviour |
| --- | --- |
| `flat_fee` | Add `surcharge_value` (money). |
| `multiplier` | Add `component × (surcharge_value − 1)`. |
| `percentage` | Add `component × surcharge_value / 100`. Values are percentage points (`10.0000` = 10%). |

`pricing_equipment_surcharges` is unique per `(version, equipment)`, supports `flat_fee` and `multiplier`, and is keyed to `vehicle_equipment_catalog` (e.g. refrigeration unit, tail lift).

Surcharge amounts are computed against the running base + distance + time + weight/volume component. Multiple equipment surcharges are summed, not compounded.

---

## 8. Time multipliers and stacking rules

`pricing_time_multipliers` stores named windows:

- `days_of_week smallint[]` using PostgreSQL DOW (`0 = Sunday`, `6 = Saturday`);
- `start_time`, `end_time`, `timezone`;
- `multiplier` between `1.0` and `5.0`;
- `priority` and `stacks`.

A window whose `end_time` is earlier than `start_time` crosses midnight. The seed's night rate is stored as `22:00 → 05:00`. For this reason the constraint is `end_time <> start_time` rather than the stricter `end_time > start_time`; a literal `22:00 → 05:00` cannot satisfy the latter.

Evaluation in `quote_preview()`:

1. Find all non-stacking matches. Apply **only the highest-priority one** (ties break by creation time).
2. Apply **every stacking match** multiplicatively on top of that.

Overlap prevention applies only when `stacks = false`. Stacking windows may overlap by design. The seed's weekend window (`Sat–Sun`, all day, `stacks = true`) can therefore coexist with the night window; at Saturday 23:00 both apply.

`applies_to` (`subtotal`, `base_fare`, `distance`, `time`) is stored for the Phase 4 engine. The preview applies all matched multipliers to the subtotal.

---

## 9. Zone multipliers

`pricing_zone_multipliers` is unique per `(version, service_zone)`. It is the non-real-time surge-like modifier for a zone:

```sql
insert into public.pricing_zone_multipliers (
  pricing_plan_version_id, service_zone_id, multiplier, reason
) values (
  :version_id, '66666666-0000-4000-8000-000000000001', 1.15,
  'CBD evening congestion'
);
```

`quote_preview()` multiplies the pre-multiplier fare by the matching zone multiplier. Zone multipliers are part of the immutable version: changing a zone multiplier is a new version.

Phase 1's `zone_pricing_overrides` is wired in two ways:

1. `zone_pricing_overrides.pricing_plan_id` now has an FK to `pricing_plan_versions(id)` (`ON DELETE RESTRICT`).
2. `zone_pricing_override_resolution` records which version an override resolved to and when.

`public.zone_pricing_override_plan_version(override_id)` reads the referenced version's plan and returns the plan version active for the override window (using `now()` when inside the window, otherwise the override's `effective_from`).

---

## 10. LATRA-regulated tariffs

`regulated_tariffs` is the per-country legal framework:

- `regulatory_body` (`LATRA`, `NTSA`, `UNRA`, …);
- optional `vehicle_type_id` (`NULL` = all goods vehicles);
- approval reference and dates;
- `tariff_structure` (`distance_band`, `weight_band`, `distance_and_weight_band`, `percentage_of_market`, `flat`);
- currency and effective window.

`regulated_tariff_bands` holds legal slices with `min_fare` and `max_fare`. Types are `distance`, `weight`, `combined`; units are `km`, `kg`, `tonnes`, `m3`. Bands of the same type may not overlap.

A version becomes regulated by setting `regulated_tariff_id`. `quote_preview()` then:

1. computes the normal fare;
2. calls `public.regulated_max_fare(tariff_id, distance_km, weight_kg)`;
3. caps the **total** at that value if the computed total is higher.

`regulated_max_fare()` returns the **minimum** `max_fare` across all applicable distance and weight bands. A legal tariff must satisfy every applicable band, so the tightest cap wins. It returns `NULL` when no band applies.

When a cap applies, `quote_preview()` re-derives `subtotal` and `vat` from the capped total so the returned breakdown stays internally consistent (`subtotal + vat = total`). The uncapped computation is still visible at `breakdown_details.pre_regulated_total`. `is_capped` is `true`.

Enforcement is layered:

- **Schema:** the tariff and bands are data, overlap is blocked, and the version can only reference a tariff.
- **Application:** Phase 4's authoritative quote engine must call `regulated_max_fare()` (or reuse `quote_preview()` logic) and refuse to persist a total above it.
- **Verification:** the Phase 3 gate proves `quote_preview()` caps at the legal maximum and never exceeds `regulated_max_fare()` for the same inputs.

A database `CHECK` cannot compare a computed quote to a band lookup, so this rule is intentionally enforced in the application helper plus the gate.

---

## 11. Version lifecycle

```text
draft  ──publish──▶  published  ──new version published──▶  superseded
  │                       │                                    │
  │ editable              │ immutable                          │ immutable, historical
  │ no effective_to       │ effective_to may be NULL           │ effective_to set once
  │ published_at NULL     │ quote engine may select it         │ never selected again
```

Rules:

- Version numbers start at `1` and increase per plan.
- `UNIQUE(pricing_plan_id, version_number)`.
- `effective_to IS NULL OR effective_to > effective_from`.
- A published row cannot be updated or deleted by application users.
- `superseded_by_version_id` points forward to the successor.
- Historical versions and their rate rows are retained forever.

`active_pricing_plan_version(plan_id, at_time)` selects the published version where `effective_from <= at_time < effective_to` (or open-ended), highest version number first.

`active_pricing_plan_for(city_id, zone_id, vehicle_type_id, at_time)` resolves the plan:

1. active plan in the city;
2. zone-specific plan beats city-wide;
3. vehicle type may be the plan's primary type or a version-level additional type;
4. ties break by `display_order` then `code`.

---

## 12. How to roll back a published version

There is no “unpublish” and no deletion. To roll back:

1. Create a new draft from the last known-good version.

   ```sql
   select public.draft_pricing_plan_version(:plan_id);
   ```

2. If the draft was copied from the bad version, restore the old values (or copy the old version's rates manually into the draft).
3. Set `effective_from` to the rollback time.
4. Publish it.

The “bad” version remains in history, correctly closed and superseded. Quotes issued under it remain explainable. This is intentional: financial and legal history must be append-only.

Do not attempt to edit the old version. The immutability trigger will reject it.

---

## 13. Promo codes: validity versus eligibility

**Validity** is what `promo_code_valid(promo_id, profile_id, at_time)` checks:

- `is_active`;
- `valid_from <= at_time < valid_to`;
- country matches the profile's default country (or is `NULL` for all countries);
- global redemption limit not reached;
- per-user redemption limit not reached;
- `new_users_only` rule: account age ≤ 30 days **and** no prior redemption by that profile.

**Eligibility** is richer targeting in `promo_code_eligibility_rules`:

- `min_jobs_completed`;
- `min_account_age_days`;
- `specific_zone`;
- `specific_day_of_week`;
- `first_job`.

**Cart-dependent filters** on `promo_codes` (`applicable_vehicle_type_ids`, `applicable_city_ids`, `applicable_cargo_type_ids`) require the booking request. Phase 4's quote engine evaluates them, plus the advanced eligibility rules, before creating a `promo_redemptions` row.

Discount semantics:

- `flat_amount`: subtract `discount_value`;
- `percentage`: subtract `discount_value` percent;
- `capped_percentage`: percentage capped at `max_discount_amount`;
- `free_ride`: full fare waiver, subject to limits and caps.

`promo_redemptions` is append-only and server-write only. No client INSERT/UPDATE/DELETE grant exists. Phase 4 will insert redemptions through the service role when a quote is accepted.

`promo_code_active` shows currently valid codes and redemption counts. It is `security_invoker`, so a normal user's count only includes redemptions visible to them; promo managers with `view_promotions` see the full count.

---

## 14. How quotes will reference a version

Phase 4 will add `quote_history` (or equivalent) with:

```text
pricing_plan_version_id  uuid not null references pricing_plan_versions(id)
pricing_plan_id          uuid not null
base_fare_snapshot       numeric(14,2)
...
```

The quote stores the **version id**, never a “current version” pointer. To reproduce a quote:

1. load the version row;
2. load its base rates and rule rows;
3. re-run the calculation;
4. compare against the stored breakdown.

Because the version is immutable, reproduction is exact. The quote may also snapshot the computed breakdown for audit convenience, but the version reference remains the source of truth.

`active_pricing_plan_for()` is the resolver Phase 4 should call to pick a plan for a request; it returns the plan id, and `active_pricing_plan_version()` returns the version id.

---

## 15. `quote_preview()` — what it does and does not do

Signature:

```sql
public.quote_preview(
  pricing_plan_version_id uuid,
  distance_km numeric,
  duration_min numeric,
  weight_kg numeric,
  volume_m3 numeric,
  cargo_type_id uuid,
  equipment_ids uuid[],
  zone_id uuid,
  at_time timestamptz default now()
) returns jsonb
```

It returns:

```json
{
  "base_fare": 5250.00,
  "distance_charge": 9600.00,
  "time_charge": 1000.00,
  "weight_surcharge": 0.00,
  "volume_surcharge": 0.00,
  "cargo_surcharge": 5000.00,
  "equipment_surcharge": 0.00,
  "zone_multiplier": 1.0000,
  "time_multiplier": 1.3000,
  "waiting_charge": 0.00,
  "multi_stop_charge": 0.00,
  "subtotal": 27105.00,
  "vat": 4878.90,
  "total": 31983.90,
  "currency_code": "TZS",
  "regulated_max_fare": null,
  "is_capped": false,
  "breakdown_details": { }
}
```

It **does**:

- resolve distance tier slices and fallback distance;
- apply weight/volume tier surcharges;
- apply cargo and equipment surcharges;
- apply the minimum charge;
- apply zone and time multipliers;
- compute VAT;
- apply the regulated cap;
- return a detailed breakdown.

It **does not**:

- persist anything;
- create a quote or a `quote_history` row;
- apply promo codes or create redemptions;
- evaluate advanced promo eligibility or cart filters;
- charge waiting time or extra stops (no parameters yet);
- apply commission, driver payouts or loyalty;
- perform real-time demand surge (zone multipliers are static version data).

It is a preview/consistency helper, not the authoritative Phase 4 quote engine.

---

## 16. Multi-country pricing

Nothing in Phase 3 is Tanzania-specific in code. Country-specific pricing is data:

```sql
-- Kenya plan
insert into public.pricing_plans (
  country_id, city_id, vehicle_type_id, code, name
) values (
  '33333333-0000-4000-8000-000000000002',  -- Kenya
  :nairobi_city_id,
  :kenya_van_type_id,
  'nbo-van-standard', 'Nairobi Small Van Standard'
);

-- Kenya regulator tariff
insert into public.regulated_tariffs (
  country_id, regulatory_body, name, approval_reference,
  approval_date, effective_from, tariff_structure, currency_code
) values (
  '33333333-0000-4000-8000-000000000002', 'NTSA',
  'NTSA Goods Transport Tariff 2026', 'NTSA/GT/2026/001',
  '2026-01-01', '2026-01-01 00:00:00+03',
  'distance_and_weight_band', 'KES'
);
```

Rules for a new country:

- create or reuse the country's `vehicle_types` (country-scoped or global);
- create plans with codes prefixed by city/region;
- create tariffs with the correct `regulatory_body`, currency and bands;
- add any country-specific cargo types/equipment in Phase 2 catalogues;
- do not hardcode currency, timezone, tax rate or regulator in functions.

`quote_preview()` returns the currency stored on the version's base rates. If a plan is priced in KES, the quote is in KES.

`pricing_plans` includes `country_id` and a trigger enforces that the city, zone and vehicle type all belong to that country. A plan cannot accidentally mix Nairobi with a Tanzanian zone.

---

## 17. Known limitations deferred to Phase 4

- **No `quote_history` yet.** Phase 4 persists authoritative quotes and the version id they used.
- **No jobs pricing columns.** Phase 4 links accepted quotes to jobs.
- **No real-time surge.** Phase 3 has static `pricing_zone_multipliers`. Phase 4 can add demand data and produce time-varying multipliers, but the version model still applies: if the multiplier is part of the priced ruleset, publish a new version.
- **No per-driver commission.** Phase 5 adds `commission_rules`; Phase 2's `fleets.commission_rate_override` is untouched.
- **No payouts.** Phase 5.
- **No loyalty tiering.** Phase 5.
- **No promo stacking across multiple codes.** Phase 4 should decide whether one or more codes apply; Phase 3 models individual codes and redemptions.
- **No waiting/extra-stop inputs in `quote_preview()`.** Phase 4's engine will pass them.
- **`loan`/financing pricing, insurance and tolls** are not modelled yet.
- **`applies_to` on time multipliers** is metadata until Phase 4 applies multipliers to specific components.
- **Advanced promo eligibility** (`min_jobs_completed`, `first_job`, `specific_zone`, `specific_day_of_week`) is stored but not evaluated by `promo_code_valid()` because jobs/booking context does not exist yet. Phase 4 evaluates it.
- **Regulated cap enforcement is application-layer**, not a database `CHECK`, because it compares a computed total to a band lookup. Phase 4 must not persist a total above `regulated_max_fare()`.
- **`quote_preview()` treats the cap as a total including VAT** and re-derives net/VAT. If compliance requires the cap to apply to the net fare instead, adjust the helper and document the change.

---

## 18. Running the gate

From the repository root:

```bash
# Local Supabase CLI (path may differ by install)
SUPABASE=/home/pallangyo/.npm/_npx/b96a6bd565c470ce/node_modules/@supabase/cli-linux-x64/bin/supabase
$SUPABASE db reset

# Set LOCAL_DB_URL to your local connection string, e.g.
# export LOCAL_DB_URL="postgresql://postgres@127.0.0.1:54322/postgres"
psql "$LOCAL_DB_URL" \
  -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-3-schema.sql

psql "$LOCAL_DB_URL" \
  -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-2-schema.sql

psql "$LOCAL_DB_URL" \
  -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-1-schema.sql
```

Or, when using the Docker container directly:

```bash
docker exec -i supabase_db_safeshift psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/scripts/verify-phase-3-schema.sql
```

Expected final lines:

```text
PHASE 3 SCHEMA VERIFICATION: 150 PASS, 0 FAIL
PHASE 2 SCHEMA VERIFICATION: 166 PASS, 0 FAIL
PHASE 1 SCHEMA VERIFICATION: 150 PASS, 0 FAIL
```

The Phase 3 script creates temporary `verify-*` plans/versions for the immutability, publish and resolution tests, then deletes them. It is safe to re-run against a disposable local/test database. It does not modify seeded plans, rates, promos or tariffs.

### Seed note

`seed-phase-3.sql` seeds:

- 1 LATRA tariff and **10** bands (6 distance + 4 weight, matching the seed specification; the verification count is 10);
- 6 Dar es Salaam plans and 7 published versions (6 × v1 plus the van v2);
- a published van v2 that is created through `draft_pricing_plan_version()` and `publish_pricing_plan_version()`, demonstrating the real workflow;
- 5 promo codes and 3 eligibility rules;
- the Phase 1 Central zone override resolved to the active van version;
- `pricing_changed` audit rows for every seeded publish.

### Implementation notes

- `zone_pricing_overrides.pricing_plan_id` FK is installed by an idempotent routine invoked in `0037` and again in `0040` after `pricing_plan_versions` exists. PostgreSQL cannot add a FK to a table that does not yet exist, so the split is a dependency-order necessity.
- Phase 1's verification guard previously asserted that `pricing_plans` did not exist. It now guards only genuine Phase 4+ tables (`jobs`, `payments`, `disputes`, `payouts`, `payment_methods`, `quote_history`), because Phase 3 legitimately creates `pricing_plans`.
- Migration `0049` installs the three genuinely new Phase 3 permissions (`manage_pricing`, `manage_regulated_tariffs`, `view_promotions`). `manage_promotions` already exists in the Phase 1 permission seed; `seed-phase-3.sql` grants it to the finance/operations roles after Phase 1 seed data is present. `seed.sql` and `seed-phase-2.sql` are left untouched.
- Surcharge/money tables have their own `currency_code` even when a row uses a multiplier. This satisfies the “every monetary table carries a currency” rule and keeps flat fees unambiguous.
- The verification script impersonates an authenticated super-admin (via JWT claims + `SET LOCAL ROLE authenticated`) to prove the immutability trigger, not merely the absence of a grant, blocks writes. It checks the error text contains the immutability message.
