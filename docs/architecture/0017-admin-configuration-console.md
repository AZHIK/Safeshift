# The Admin Configuration Console

- **Status:** Implemented locally; staging and device verification pending
- **Date:** 2026-11-12
- **Scope ADR:** `docs/architecture/0016-phase-9-remaining-flows.md`
- **Migrations:** `supabase/migrations/0132_phase_10_admin_config_permissions.sql`,
  `supabase/migrations/0133_phase_11_countries_management.sql`
- **Console code:** `apps/admin-console/app/(console)/settings/configuration/`,
  `apps/admin-console/components/configuration/`,
  `apps/admin-console/lib/configuration/`
- **Manual checklist:** `docs/testing/phase-9-config-manual-tests.md`

> Note: this document uses the filename requested by the configuration brief.
> The repository already had `0017-phase-8-client-integration.md`; both files are
> kept because that document is still referenced by the Phase 8 material.

## 1. Overview of the Configuration section

The Configuration section is the operator toolkit of the SafeShift admin
console. It is the set of pages that let an operations team run the platform
without a developer: add a vehicle type for a new city, tighten a cargo
restriction, translate a notification, flip a feature flag, tune the dispatch
rules after watching real match times, or grant a colleague an admin role.

Twenty configuration tables are exposed, one page each, under
`/settings/configuration`:

| Group            | Page                                              | Table                              | Permission                     |
| ---------------- | ------------------------------------------------- | ---------------------------------- | ------------------------------ |
| Geography        | `/settings/configuration/countries`               | `countries`                        | `manage_countries`             |
| Vehicles         | `/settings/configuration/vehicle-types`           | `vehicle_types`                    | `manage_vehicle_catalog`       |
| Vehicles         | `/settings/configuration/vehicle-makes`           | `vehicle_makes`                    | `manage_vehicle_catalog`       |
| Vehicles         | `/settings/configuration/vehicle-models`          | `vehicle_models`                   | `manage_vehicle_catalog`       |
| Vehicles         | `/settings/configuration/vehicle-equipment`       | `vehicle_equipment_catalog`        | `manage_vehicle_catalog`       |
| Cargo            | `/settings/configuration/cargo-categories`        | `cargo_categories`                 | `manage_cargo_catalog`         |
| Cargo            | `/settings/configuration/cargo-types`             | `cargo_types`                      | `manage_cargo_catalog`         |
| Cargo            | `/settings/configuration/cargo-restrictions`      | `cargo_restrictions`               | `manage_cargo_catalog`         |
| Cargo            | `/settings/configuration/cargo-packaging`         | `cargo_packaging_options`          | `manage_cargo_catalog`         |
| Verification     | `/settings/configuration/document-types`          | `document_types`                   | `manage_document_types`        |
| Verification     | `/settings/configuration/verification-checklists` | `verification_checklist_templates` | `manage_document_types`        |
| Support & Safety | `/settings/configuration/prohibited-items`        | `prohibited_items`                 | `manage_prohibited_items`      |
| Support & Safety | `/settings/configuration/support-categories`      | `support_categories`               | `manage_support`               |
| Communication    | `/settings/configuration/notification-templates`  | `notification_templates`           | `manage_notifications`         |
| Communication    | `/settings/configuration/localization-strings`    | `localization_strings`             | `manage_localization`          |
| Platform         | `/settings/configuration/feature-flags`           | `feature_flags`                    | `manage_features`              |
| Platform         | `/settings/configuration/cancellation-policies`   | `cancellation_policies`            | `manage_cancellation_policies` |
| Platform         | `/settings/configuration/dispatch-rules`          | `dispatch_rules`                   | `manage_dispatch`              |
| Platform         | `/settings/configuration/rating-categories`       | `rating_categories`                | `manage_ratings`               |
| Administration   | `/settings/configuration/admin-roles`             | `admin_roles`                      | `manage_admins`                |
| Administration   | `/settings/configuration/permissions-catalog`     | `admin_role_permissions`           | `manage_admins`                |

Every page follows the same shape:

- a sub-navigation on the left listing the twenty-one pages, filtered to the
  pages the signed-in administrator may open;
- a filter bar (search, active/inactive, country) above the table;
- a table with pagination and a row action column (Edit, Deactivate, Audit);
- a create/edit modal dialog driven by a declarative field definition;
- an audit history drawer for every row.

Nothing in this section touches financial records, pricing plans, promos or
tariffs: those have their own pages from Phase 9.

### 1.1 What the section is not

It is not a bulk editor. Every row is saved on its own, there is no CSV
import, and there is no staging area: a change is live the moment it is
saved. Section 10 lists what that costs.

## 2. The permission model

### 2.1 The source of truth

Permissions live in `public.admin_permissions_catalog` and are granted to roles
through `public.admin_role_permissions`. `public.has_permission(permission_key)`
answers the question "may this administrator do this?", honouring the country
scope and the expiry of the grant.

The console never keeps its own copy of the rules. Every page calls
`requireConfigurationPermission(permission)` before it renders, and every
server action calls `withAdminPermission(permission, ...)` before it writes.
Both read the caller's permissions through `public.admin_my_permissions()`.

### 2.2 The umbrella permission

Migration `0132` adds `manage_configuration`. A holder of it satisfies a check
for any permission in `public.config_permission_keys()`:

```
manage_vehicle_catalog, manage_cargo_catalog, manage_document_types,
manage_support, manage_prohibited_items, manage_notifications,
manage_localization, manage_features, manage_cancellation_policies,
manage_dispatch, manage_ratings, manage_countries
```

The umbrella is implemented inside `public.has_permission()` itself, so the
row-level security policies of the twenty-one tables honour it as well. Without
that, a holder of the umbrella would pass the console's own check and then be
rejected by the database on every write.

**The umbrella deliberately does not include `manage_admins`.** Granting admin
roles is a different class of change from editing a catalogue: if the umbrella
covered it, an operations administrator who held it could grant themselves
`super_admin` and escalate. The Administration pages therefore always require
`manage_admins` explicitly, which in practice means a super admin.

### 2.3 Who can see what

| Role                 | Configuration pages                                                                 |
| -------------------- | ----------------------------------------------------------------------------------- |
| `super_admin`        | all twenty-one (it holds every permission in the catalogue, including the umbrella) |
| `operations_admin`   | Countries, Vehicles, Cargo, Verification, Dispatch Rules, Cancellation Policies     |
| `verification_admin` | Document Types, Verification Checklists                                             |
| `support_agent`      | Support Categories                                                                  |
| `finance_admin`      | none                                                                                |
| `analyst`            | none                                                                                |
| `fleet_owner`        | none                                                                                |

The sidebar shows the Configuration section when the administrator holds
`manage_configuration` or any one of the fourteen configuration permissions,
and lists only the pages that administrator may open.

### 2.4 Two layers of enforcement

1. **The console** checks the permission before it renders the page and before
   it writes. A customer account that somehow reaches the console is stopped
   here: `getAdminSession()` returns nothing without an active admin role, and
   the page guard redirects to the dashboard.
2. **The database** checks the same permission through the row-level security
   policies written in Phases 1–6. A write that slips past the console is
   rejected by Postgres.

The console uses the signed-in administrator's session rather than the
service-role key, exactly as the rest of the console does. That keeps RLS
authoritative and, because `auth.uid()` is set on the request, gives
`private.audit_trigger()` the real actor for every row it writes.

## 3. The CRUD pattern

### 3.1 The resource definition

Every page is described by a `ConfigResource` in
`apps/admin-console/lib/configuration/resources/`. It is plain data: the
table, the columns, the fields, the permission, the uniqueness rules, the
reference counts and the cross-field rules. Because it carries no React and no
database client, the same object is read by the server (to query and
validate) and by the client (to render the table and the form).

### 3.2 The five operations

| Operation      | What it does                                                                                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **List**       | `listX(filters)` reads the table through the session client, applies the search, the status filter, the country filter and the pagination, then flattens the embedded relations into the column names the table declares. |
| **Create**     | `createX(values)` validates the values, checks the uniqueness rules, inserts the row and writes the audit entry.                                                                                                          |
| **Update**     | `updateX(id, values)` validates, checks uniqueness excluding the row itself, updates and writes the audit entry with only the fields that changed.                                                                        |
| **Deactivate** | `deactivateX(id, reason)` counts what still references the row, refuses when live data depends on it, and otherwise sets `is_active = false`.                                                                             |
| **Audit**      | `getXAuditHistory(id, filters)` reads the merged trail of the row.                                                                                                                                                        |

There is also `deleteX(id)`, used only by the two tables that have no
`is_active` column and that nothing references (see section 4).

### 3.3 The shared engine

The twenty action files are thin. They call
`apps/admin-console/lib/configuration/action-helpers.ts`, which calls
`apps/admin-console/lib/configuration/server.ts`. The engine owns the four
things that must not vary between tables:

- `withAdminPermission(permission, callback)` — the permission check;
- `validateValues(resource, values)` — the input validation, including the
  declarative cross-field rules;
- `logAdminAction(...)` — the console action trail;
- `getReferencingCounts(resource, id)` — the deactivate guard.

Each page's `actions.ts` exports six named server actions, so there are 120 in
total:

```ts
export async function createVehicleType(values: ConfigFieldValues) {
  return createConfigurationRecord(vehicleTypes, values);
}
```

### 3.4 The form

The create and edit dialog is one component
(`components/configuration/configuration-form-dialog.tsx`). The edit dialog
opens with the row's values already filled in; the create dialog opens with
the defaults. The fields are declarative:

```ts
{
  name: 'capacity_kg_max',
  label: 'Maximum capacity (kg)',
  type: 'number',
  required: true,
  min: 1,
}
```

Supported types: `text`, `textarea`, `number`, `select`, `multi-select`,
`checkbox`, `json`, `date`, `tags` and `profile` (the profile search used by
the Admin Roles page).

Validation runs in two places. The form validates the declarative rules as
the operator types, so an obvious mistake never reaches the server. The
server validates again before it writes, because the server is the only place
that can be trusted.

## 4. Why most deletes are soft deletes

A configuration row is usually referenced by something that has already
happened. A vehicle type is referenced by vehicles, by pricing plans and by
quote requests; a cargo type is referenced by quote requests and by pricing
surcharges; a document type is referenced by driver and vehicle documents.
Deleting the row would either fail on a foreign key or, worse, succeed and
detach live history from the configuration that explains it.

So the console deactivates: it sets `is_active = false`. The row stays, the
history stays, and the apps stop offering the row because they all filter on
`is_active`.

The console refuses to deactivate a row that live data still uses, and says
what is in the way:

> This vehicle type is still referenced by 3 active vehicles, 1 pricing plans.
> Deactivate it only once nothing uses it.

The counts come from `public.admin_config_reference_counts()`
(migration `0132`). The count is taken inside the database because the
operational tables carry row-level security policies that would otherwise hide
live references from an operations administrator. The function counts only:
no row contents and no personal data leave it, and the table and column pairs
are fixed in the function body.

Two tables are hard-deleted, because they have no `is_active` column and
nothing points at them:

- **feature flags** — a flag is either enabled or it is not, and a flag that
  is no longer wanted should leave no trace;
- **role permission grants** — the grant itself is the thing being managed.

One table deviates on purpose. **Admin role grants are revoked, not deleted**:
the row records who held the role, who granted it and when, and deleting it
would erase that history, which `admin_actions_log` cannot reconstruct. A
revoke sets `is_active = false` and stamps `revoked_at` and
`revoked_reason`.

## 5. The audit trail architecture

Two trails run side by side.

### 5.1 The row-level trail

`private.audit_trigger()` is attached to the twenty-one tables (Phases 1–7). It
fires on every INSERT, UPDATE and DELETE **inside the same transaction as
the change**, so no mutation can happen without a trail. It records the
actor, the action, the whole old row and the whole new row.

### 5.2 The console action trail

`public.admin_actions_log` is the queryable admin trail: who did what, under
which role, with which permission, when, from which IP. Every console mutation
writes one row through `public.admin_log_action()`, a SECURITY DEFINER
function that the authenticated role cannot call directly.

The console action trail says _what the operator was trying to do_; the
row-level trail says _exactly which columns changed_. The audit drawer shows
both.

### 5.3 The audit drawer

Every row has an Audit button. It opens a drawer showing the last 50 entries
for that record:

- timestamp, actor, action, old value, new value;
- a filter by date range and by actor;
- an "Export to CSV" button;
- "Showing the last 50 — view all in the audit viewer" when there are more.

The merged trail is read through `public.admin_audit_history()`, which is
permission-checked (the page permission, the umbrella, or `view_audit`) and
which **masks personal data before it leaves the database**:
`private.mask_pii_text()` removes email addresses and separator-formatted
phone numbers from free text, and `private.mask_pii_json()` replaces the
values of keys such as `phone`, `email` and `token` outright. A configuration
row never holds personal data, but the same reader is used for every entity
type, so the masking is unconditional.

### 5.4 The two administration audits

Granting, revoking and creating permissions are audited separately
(`permission.granted`, `permission.revoked`, `permission.created`) because
they change who can do what.

## 6. Multi-country configuration

SafeShift launches in Tanzania and expands across East Africa, so country
scoping is built in from the first table rather than bolted on.

### 6.1 The rules

- A table with a `country_id` column is country scoped. A row with
  `country_id = NULL` applies to **every** country; a row with a country
  applies to that country only.
- The country is chosen in the form ("Applies to"), and the list shows a
  scope badge on every row: either the country name or "All countries".
- The filter bar can narrow the list to one country.
- Uniqueness is per scope. `vehicle_types` has a unique key on
  `(country_id, code)`, so Tanzania may have a `pickup_van` and Kenya may have
  a different `pickup_van` with its own capacity.
- Tables with no `country_id` are global: vehicle makes, vehicle equipment,
  cargo categories, cargo packaging options, rating categories, the
  localisation strings, the notification languages and the dispatch rules that
  deliberately apply everywhere.

### 6.2 Reading the scope

The scope is shown in three places so an operator cannot miss it:

1. the scope badge in the table;
2. the "Applies to" field in the form, whose empty option is labelled "All
   countries" rather than a blank;
3. the country filter in the toolbar, which defaults to "All countries" so
   that the default view shows the global rows too.

## 7. Adding a new configuration table to the console

The pattern is the same for every table. A new one takes about six steps.

**1. Write the resource definition.**
Create `apps/admin-console/lib/configuration/resources/<group>.ts` and export
a `ConfigResource`:

```ts
export const widgetTypesResource: ConfigResource = {
  table: 'widget_types',
  singular: 'widget type',
  singularTitle: 'Widget Type',
  pluralTitle: 'Widget Types',
  description: 'One sentence an operator reads before changing anything.',
  permission: 'manage_widgets',
  group: 'Platform',
  countryScoped: true,
  softDelete: true,
  selectSpec: 'id, code, name, country_id, is_active, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'code'], label: 'code in this country' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name' },
    { key: 'is_active', label: 'Status', kind: 'boolean' },
  ],
  searchColumns: ['code', 'name'],
  fields: [
    { name: 'country_id', label: 'Applies to', type: 'select', optionsKey: 'countries' },
    { name: 'code', label: 'Code', type: 'text', required: true },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
};
```

**2. Register it.** Add it to `resources/index.ts`: the export alias, the
`CONFIGURATION_RESOURCES` entry, the navigation item and the
`CONFIGURATION_SLUG_BY_TABLE` entry.

**3. Add the permission.** Insert it into `admin_permissions_catalog` and
grant it to the roles that need it. If the permission is new, add a migration
rather than editing an old one.

**4. Write the actions.** Create
`app/(console)/settings/configuration/<slug>/actions.ts` with the six named
actions; copy the shape of an existing file.

**5. Write the page.** Create `app/(console)/settings/configuration/<slug>/page.tsx`:
check the permission, load the options, load the first page of rows, and hand
everything to `ConfigurationClient`.

**6. Check the row-level security policy.** The table needs a SELECT policy
for `authenticated` and an INSERT/UPDATE/DELETE policy gated on the
permission. Without them the console can render the page but cannot write.

Then add a test to `__tests__/permissions.test.ts` that asserts the page
requires the right permission.

## 8. The test data warning

**A configuration change is live the moment it is saved.**

There is no draft mode, no preview of production and no approval step. When
an operator deactivates a cargo type, the customer app stops offering it in
the next request it makes. When an operator edits a dispatch rule, the next
job to be matched uses the new numbers. When an operator grants a permission,
every holder of that role has it on their next request.

This is deliberate: the console is for operators who need a change to take
effect now, and a staging step would mean the operator maintains two
configurations and never knows which one is live.

The mitigations are the ones already in the design:

- the **audit drawer** shows exactly what changed and who changed it;
- the **deactivate dialog** lists what still references the row, and refuses
  when live data depends on it;
- the **scope badge** shows whether a row is global or country-specific;
- the **special panels** (pricing coverage, fee calculator, rule resolution,
  template preview) let an operator see the effect before saving where a
  preview is possible.

The Localization Strings page adds one more: a **missing translations**
filter that narrows the list to the keys that are not yet translated into
every language of the catalogue.

The staging and production databases are separate. A configuration change
made in staging never reaches production; the seed files are what carry the
configuration forward.

## 9. Common operator tasks

### 9.1 Adding a new vehicle type for a new city

1. Open **Configuration → Vehicles → Vehicle Types**.
2. Check the **Pricing coverage** panel on the right. If the type you are
   about to add is one the platform cannot price yet, finish step 4 first.
3. Click **New vehicle type**.
4. In **Applies to**, leave the country empty for a global type, or choose the
   country the type belongs to. A type that only exists in one country must
   not be global, or it appears in every market's booking screen.
5. Give it a **code** (lower case, underscores), a **name**, the capacity
   range in kilograms, and optionally the volume range, the maximum
   dimensions and the number of wheels.
6. Tick **Requires a special licence** if a driver needs a special permit to
   drive it, and pick the **required equipment** the driver must carry.
7. Save. The new type appears in the list and, because the apps read the
   catalogue live, in the customer booking screen.
8. Open the **Pricing** column on the new row. If it says "No pricing", the
   type is bookable but cannot be priced: add a pricing plan for it in
   **Pricing & tariffs** before you leave it live.

### 9.2 Adding a new cargo type with restrictions

1. Open **Configuration → Cargo → Cargo Types** and click **New cargo type**.
2. Choose the **category** (under Cargo Categories) and the **country scope**.
3. Give the cargo type a **code** and a **name**.
4. Tick **Requires special handling** for anything that needs a trained
   driver or special equipment, **Requires a declared value** for anything
   whose value must be declared on the quote, and **Requires insurance** for
   anything the platform must see insured.
5. Choose the **allowed vehicle types**. Leaving the list empty means any
   vehicle type may carry it; naming vehicle types narrows it.
6. Choose the **prohibited vehicle types**. A cargo type cannot be both
   allowed and prohibited for the same vehicle type.
7. Set the **maximum value** in shillings if the cargo has a value ceiling.
8. Save.
9. To stop it travelling with another cargo, open **Cargo → Restrictions**,
   click **New cargo restriction**, choose the cargo type, set the restriction
   type to **Cannot be combined with**, and choose the other cargo type.
   Save.

### 9.3 Translating a notification template for a new language

1. Open **Configuration → Communication → Notification Templates**.
2. Find the template by its code. The **Language** column shows which
   language the row is written in.
3. Click **Edit** on the row you want to translate from, note the body and the
   variables it uses, then close without saving.
4. Click **New template**. Choose the same **country scope**, the **new
   language**, the same **code** and the same **channel**.
5. Write the **body** in the new language. Use `{{variable}}` for every
   variable the original uses; the list of variables is in the **Variables**
   field, and the preview panel on the right shows the result with sample
   values.
6. If the template declares a variable the body does not use, the form warns
   you before you save.
7. Save. The new language now receives that notification.

### 9.4 Adjusting dispatch rules after observing real match times

1. Open **Configuration → Platform → Dispatch Rules**.
2. Use the **Resolution preview** panel on the right. Choose the country, the
   city and the vehicle type of a typical job, and the panel tells you which
   rule would apply and what its numbers are.
3. If the panel says no rule matches, the matcher is falling back to its
   built-in defaults. Add a rule.
4. Click **Edit** on the rule you want to change. Adjust the **maximum search
   radius**, the **offer timeout**, the **maximum concurrent offers** and the
   **reassign delay**.
5. Save. New jobs use the new numbers; jobs that are already out for offers
   keep the numbers they started with.

### 9.5 Deactivating a driver-visible document type after a regulation change

1. Open **Configuration → Verification → Document Types**.
2. Find the document type by its code.
3. Check what still references it: the **Audit** drawer and the deactivate
   dialog both show the counts. A document type with driver or vehicle
   documents against it cannot be deactivated until those documents are
   cleared — the console refuses and says how many are in the way.
4. If the document type is still required for new verifications but should no
   longer be _requested_, clear **Required** and save instead of
   deactivating. An existing document type that is no longer required stops
   appearing on new checklists; the documents already uploaded stay.
5. If the document type must disappear entirely, deactivate it. It stops
   appearing in the driver app straight away; documents already uploaded keep
   their history.
6. If the regulation also changed the verification checklist, open
   **Verification → Checklists**, edit the checklist for that country and
   request type, and remove the document code from the required list.

## 10. Known limitations

- **No bulk import.** There is no CSV upload. A hundred new vehicle types
  means a hundred form submissions. A future bulk importer should validate
  each row through the same rules and write them in one transaction.
- **No draft or preview mode.** A change is live the moment it is saved.
  There is no staging copy of the configuration and no approval workflow.
- **No rollback.** A wrong change has to be undone by editing the row again
  or by reactivating it. The audit drawer shows what the row looked like
  before, which is what makes a manual revert possible, but the console does
  not offer a one-click "go back to this version".
- **The audit drawer shows the last 50 entries.** The full trail is in the
  audit viewer; the drawer is deliberately a summary.
- **The profile search needs two characters.** The search runs through the
  database helper that records the personal-data access, and it will not scan
  the whole directory.
- **The configuration tables have no optimistic concurrency.** Two operators
  editing the same row at the same time will have the last save win.
- **The missing-translations filter reports the incomplete keys, not the
  missing rows.** A key that exists in two languages out of three is listed
  under the languages that have it; the operator creates the missing row by
  hand.

## 11. How to run the manual test checklist

The checklist lives in `docs/testing/phase-9-config-manual-tests.md`.

**What you need:**

- a local Supabase stack (`pnpm db:start`) with the migrations applied
  (`pnpm db:reset`), or a staging project with migration `0132` applied;
- the admin console running (`pnpm --filter @safeshift/admin-console dev`,
  port 3001);
- the admin accounts seeded by `supabase/seed.sql`, or equivalents you create
  yourself.

**Before you start:**

```bash
# from the repository root
corepack pnpm db:start
corepack pnpm --filter @safeshift/admin-console build
corepack pnpm --filter @safeshift/admin-console dev
```

If the permissions are missing from your database, apply the migration:

```bash
npx supabase db reset          # local: applies every migration, including 0132
```

**Running the checks.** Follow the checklist in order. Each item says what to
do, what you should see, and what to do if it fails. Sign in as each of the
four roles the checklist uses — `super_admin`, `operations_admin`,
`support_agent` and `analyst` — to check what each one can and cannot reach.

**Automated checks.** The unit tests cover the parts that can be tested
without a database:

```bash
corepack pnpm --filter @safeshift/admin-console test
corepack pnpm --filter @safeshift/admin-console lint
corepack pnpm --filter @safeshift/admin-console build
```

**Recording the result.** The checklist has a result column. Note the date,
the environment and the account for each item you ran, and file a bug for
anything that does not match.
