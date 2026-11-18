# Phase 10 — Configuration Console Manual Tests

- **Scope:** the operator Configuration section of the admin console
- **Architecture:** `docs/architecture/0017-admin-configuration-console.md`
- **Pages:** `/settings/configuration/*` (20 pages)
- **Migration under test:** `supabase/migrations/0132_phase_10_admin_config_permissions.sql`

## Before you start

```bash
# from the repository root
corepack pnpm db:start                       # local Supabase
corepack pnpm db:reset                      # applies every migration, including 0132
corepack pnpm --filter @safeshift/admin-console dev   # console on http://localhost:3001
```

You need four accounts with these admin roles:

| Account                | Role               |
| ---------------------- | ------------------ |
| `super@example.test`   | `super_admin`      |
| `ops@example.test`     | `operations_admin` |
| `support@example.test` | `support_agent`    |
| `analyst@example.test` | `analyst`          |

`supabase/seed.sql` creates the roles and the permission grants. If a role is
missing, grant it in the Permissions Catalog page or directly in the
database.

**Environment:** ☐ local ☐ staging  
**Date:** ______________  
**Tester:** ______________

---

## 1. Access control

| #    | Check                                                                                        | Expected                                                                                                                                                            | Result |
| ---- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1.1  | Sign in as `super_admin` and open `/settings/configuration/vehicle-types`                    | The page renders with a table and a **New vehicle type** button                                                                                                     | ☐      |
| 1.2  | As `super_admin`, open the sidebar                                                           | A **Configuration** section lists all twenty-one pages across the eight groups                                                                                      | ☐      |
| 1.3  | As `super_admin`, open every one of the twenty-one pages                                     | All twenty-one render without an error                                                                                                                              | ☐      |
| 1.4  | Sign in as `operations_admin` and open `/settings/configuration/vehicle-types`               | The page renders                                                                                                                                                    | ☐      |
| 1.5  | As `operations_admin`, list the sidebar Configuration entries                                | Countries, Vehicles, Cargo, Verification, Platform (dispatch rules and cancellation policies). **No** Communication, **no** Support & Safety, **no** Administration | ☐      |
| 1.6  | As `operations_admin`, open `/settings/configuration/notification-templates` directly by URL | Redirected to the dashboard with "You do not have permission to manage this configuration."                                                                         | ☐      |
| 1.7  | Sign in as `support_agent` and open `/settings/configuration/support-categories`             | The page renders                                                                                                                                                    | ☐      |
| 1.8  | As `support_agent`, list the sidebar Configuration entries                                   | Only **Support Categories**                                                                                                                                         | ☐      |
| 1.9  | As `support_agent`, open `/settings/configuration/cargo-types` directly by URL               | Redirected to the dashboard                                                                                                                                         | ☐      |
| 1.10 | Sign in as `analyst`                                                                         | The sidebar has **no** Configuration section at all                                                                                                                 | ☐      |
| 1.11 | As `analyst`, open `/settings/configuration/vehicle-types` directly by URL                   | Redirected to the dashboard                                                                                                                                         | ☐      |
| 1.12 | Sign in with a customer account (no admin role)                                              | Redirected to the login page; no configuration page is reachable                                                                                                    | ☐      |
| 1.13 | As `super_admin`, open `/settings/configuration/permissions-catalog`                         | The page renders with the warning banner "Changes to role permissions affect all users with that role immediately."                                                 | ☐      |

## 2. Reading the list

| #   | Check                                                     | Expected                                                                           | Result |
| --- | --------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------ |
| 2.1 | Open **Vehicle Types**                                    | A table with code, name, country, capacities, special licence, pricing and status  | ☐      |
| 2.2 | Look at the country column                                | A row with no country shows **All countries**; a scoped row shows the country name | ☐      |
| 2.3 | Type in the search box                                    | The list narrows as you type (after a short pause)                                 | ☐      |
| 2.4 | Use the **Status** filter                                 | "Active only" and "Inactive only" narrow the list                                  | ☐      |
| 2.5 | Use the **Country** filter                                | The list narrows to the chosen country; "All countries" shows everything           | ☐      |
| 2.6 | Open a table with more than 25 rows (seed more if needed) | The pagination controls appear and **Next** loads the following page               | ☐      |
| 2.7 | Open **Localization Strings**                             | The rows are grouped under a namespace heading                                     | ☐      |
| 2.8 | Open a table with no rows                                 | The empty state and a **Create the first one** button are shown                    | ☐      |
| 2.9 | Open **Vehicle Types** and look at the right-hand panel   | **Pricing coverage** lists the active vehicle types that have no pricing plan      | ☐      |

## 3. Creating

| #   | Check                                                                                      | Expected                                                                                                       | Result |
| --- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- | ------ |
| 3.1 | On **Vehicle Types**, click **New vehicle type** and save without filling anything in      | The dialog refuses and shows "Code is required.", "Name is required." and the capacity errors under the fields | ☐      |
| 3.2 | Fill in a code, a name and a capacity range and save                                       | The dialog closes and a success notice appears; the new row is in the list                                     | ☐      |
| 3.3 | Set the maximum capacity below the minimum and save                                        | "Maximum capacity must not be smaller than the minimum." appears under the maximum field                       | ☐      |
| 3.4 | Create a second vehicle type with the same code and the same country                       | The console refuses: "Another vehicle type already uses this code in this country."                            | ☐      |
| 3.5 | Create the same code again but for a different country                                     | It is accepted — the code is unique per country, not globally                                                  | ☐      |
| 3.6 | On **Cargo Types**, create a cargo type with a declared value and a maximum value          | The row shows the declared-value and maximum-value columns                                                     | ☐      |
| 3.7 | On **Notification Templates**, create a template for a language and open the preview panel | The preview renders the body with the sample values; a declared variable that the body does not use is flagged | ☐      |
| 3.8 | On **Dispatch Rules**, create a rule with a country, a city and a vehicle type             | The row shows the country, the city and the vehicle type                                                       | ☐      |
| 3.9 | On **Admin Roles**, click **Grant a role**, search for a profile and save                  | The grant appears with the profile name, the role and the scope                                                | ☐      |

## 4. Editing

| #   | Check                                                                              | Expected                                                                                        | Result |
| --- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------ |
| 4.1 | Click **Edit** on a vehicle type                                                   | The dialog opens with the row's values already filled in                                        | ☐      |
| 4.2 | Change the name and save                                                           | The list shows the new name and a success notice appears                                        | ☐      |
| 4.3 | Open the **Audit** drawer of that row                                              | The change is listed with the timestamp, the actor, the action, the old value and the new value | ☐      |
| 4.4 | On **Cancellation Policies**, change the fee type to **Tiered**                    | The **Fee tiers** field appears; the free window and the fee value fields stay                  | ☐      |
| 4.5 | On **Cancellation Policies**, use the **Fee calculator** panel                     | Entering minutes before pickup and a quote amount shows the fee that would be charged and why   | ☐      |
| 4.6 | On **Dispatch Rules**, use the **Resolution preview** panel                        | It names the rule that would apply for the chosen country, city and vehicle type                | ☐      |
| 4.7 | On **Cargo Restrictions**, set the restriction type to **Cannot be combined with** | The **Restricted with cargo type** field appears                                                | ☐      |
| 4.8 | On **Cargo Restrictions**, set the restriction type to **Requires a certificate**  | The **Restricted with cargo type** field disappears                                             | ☐      |

## 5. Deactivating

| #    | Check                                                                        | Expected                                                                                           | Result |
| ---- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ------ |
| 5.1  | Click **Deactivate** on a vehicle type                                       | The confirmation dialog opens and the **Deactivate** button stays disabled                         | ☐      |
| 5.2  | Type something other than `DEACTIVATE`                                       | The button stays disabled                                                                          | ☐      |
| 5.3  | Type `DEACTIVATE`                                                            | The button becomes enabled                                                                         | ☐      |
| 5.4  | Deactivate a vehicle type that an active vehicle uses                        | The console refuses: "This vehicle type is still referenced by N active vehicles…"                 | ☐      |
| 5.5  | Deactivate a vehicle type nothing uses                                       | The row becomes inactive and disappears from the customer booking screen                           | ☐      |
| 5.6  | Deactivate a cargo type that quote requests still reference                  | The console refuses and names the count                                                            | ☐      |
| 5.7  | Deactivate a cargo type nothing references                                   | It disappears from new bookings; an old job that used it still shows it                            | ☐      |
| 5.8  | Deactivate a support category with open tickets                              | The console refuses and names the count                                                            | ☐      |
| 5.9  | Deactivate a document type that driver documents reference                   | The console refuses and names the count                                                            | ☐      |
| 5.10 | On **Feature Flags**, remove a flag                                          | The row is deleted (feature flags have no active state) and the action is in the audit trail       | ☐      |
| 5.11 | On **Admin Roles**, revoke a grant                                           | The grant is deactivated and stamped as revoked; the row stays in the list with the revoked status | ☐      |
| 5.12 | Try to revoke the **last** active super admin grant                          | The console refuses: "This is the last active super admin…"                                        | ☐      |
| 5.13 | As a non-super admin with `manage_admins`, try to grant the super admin role | The console refuses: "Only a super admin may grant the super admin role."                          | ☐      |

## 6. The audit trail

| #   | Check                                                                      | Expected                                                                            | Result |
| --- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------ |
| 6.1 | Click **Audit** on a row that has been changed                             | The drawer opens with the last entries for that record                              | ☐      |
| 6.2 | The drawer shows                                                           | A timestamp, the actor name, the action, the old value and the new value            | ☐      |
| 6.3 | Set a date range and an actor                                              | The list narrows to the matching entries                                            | ☐      |
| 6.4 | Click **Export to CSV**                                                    | A CSV file downloads with one row per entry                                         | ☐      |
| 6.5 | Look at a record with more than 50 changes                                 | The note "Showing the last 50 — view all in the audit viewer" is shown              | ☐      |
| 6.6 | Open the **Audit log** page of the console                                 | Every configuration change appears there too, with the role and the permission used | ☐      |
| 6.7 | Check that a value containing an email address or a phone number is masked | The drawer shows `***@***` instead of the address                                   | ☐      |

## 7. The permissions catalog

| #   | Check                                                                          | Expected                                                                               | Result |
| --- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------ |
| 7.1 | Open **Permissions Catalog**                                                   | The table lists every role and permission grant with its description                   | ☐      |
| 7.2 | Choose a role in the right-hand panel                                          | The panel lists the permissions that role grants today, read only                      | ☐      |
| 7.3 | Click **Grant a permission** and grant `manage_dispatch` to `operations_admin` | The grant appears in the table                                                         | ☐      |
| 7.4 | Sign in as `operations_admin` again                                            | The Dispatch Rules page is now reachable                                               | ☐      |
| 7.5 | Revoke the grant                                                               | The grant disappears from the table; the operations administrator loses the page again | ☐      |
| 7.6 | Click **New permission** and create a permission                               | The permission is added to the catalogue and can be granted                            | ☐      |
| 7.7 | Try to grant a permission you do not hold yourself                             | The dialog warns you before you save                                                   | ☐      |

## 8. Effects on the platform

| #   | Check                                                                        | Expected                                            | Result |
| --- | ---------------------------------------------------------------------------- | --------------------------------------------------- | ------ |
| 8.1 | Create a new vehicle type, then refresh the customer booking screen          | The new type appears in the booking screen          | ☐      |
| 8.2 | Deactivate a cargo type, then open a new booking                             | The cargo type is no longer offered                 | ☐      |
| 8.3 | Open an old job that used the deactivated cargo type                         | The job still shows it                              | ☐      |
| 8.4 | Add a notification template and open it in the console                       | The preview renders the copy with the sample values | ☐      |
| 8.5 | Update a localisation string, then clear the app cache and reopen the screen | The new copy is used                                | ☐      |
| 8.6 | Turn on a feature flag for a country and open the app in that country        | The feature is active there                         | ☐      |
| 8.7 | Turn on a feature flag for a city                                            | The feature is active in that city only             | ☐      |
| 8.8 | Edit a dispatch rule, then create a job                                      | The new job uses the updated numbers                | ☐      |
| 8.9 | Grant a new permission to a role, then sign in as a holder of that role      | The holder has the new access on the next request   | ☐      |

## 9. Regression checks

| #   | Check                                                                                                                                                                                                                                | Expected                                                            | Result |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | ------ |
| 9.1 | Open the **Dashboard**                                                                                                                                                                                                               | It loads as before                                                  | ☐      |
| 9.2 | Open **Catalogue**                                                                                                                                                                                                                   | The vehicle categories and cargo types load and can still be edited | ☐      |
| 9.3 | Open **Users**, **Drivers**, **Jobs**, **Payments**, **Payouts**, **Disputes**, **Support**, **Incidents**, **Data requests**, **Pricing**, **Promos**, **Analytics**, **Fleets**, **Verifications**, **Audit log** and **Settings** | Each page loads as before                                           | ☐      |
| 9.4 | Sign out and sign in again                                                                                                                                                                                                           | The session still works                                             | ☐      |
| 9.5 | Open the console on a phone-sized window                                                                                                                                                                                             | The configuration pages reflow into a single column and stay usable | ☐      |

## 10. Automated checks

| #    | Command                                                 | Expected                                                     | Result |
| ---- | ------------------------------------------------------- | ------------------------------------------------------------ | ------ |
| 10.1 | `corepack pnpm --filter @safeshift/admin-console test`  | All the tests pass                                           | ☐      |
| 10.2 | `corepack pnpm --filter @safeshift/admin-console lint`  | No errors, no warnings                                       | ☐      |
| 10.3 | `corepack pnpm --filter @safeshift/admin-console build` | The build succeeds and lists the twenty configuration routes | ☐      |

---

## Result summary

| Section                    | Passed | Failed | Blocked | Notes |
| -------------------------- | ------ | ------ | ------- | ----- |
| 1. Access control          |        |        |         |       |
| 2. Reading the list        |        |        |         |       |
| 3. Creating                |        |        |         |       |
| 4. Editing                 |        |        |         |       |
| 5. Deactivating            |        |        |         |       |
| 6. The audit trail         |        |        |         |       |
| 7. The permissions catalog |        |        |         |       |
| 8. Effects on the platform |        |        |         |       |
| 9. Regression checks       |        |        |         |       |
| 10. Automated checks       |        |        |         |       |

**Sign-off:** ______________ **Date:** ______________
