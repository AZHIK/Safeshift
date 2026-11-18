#!/usr/bin/env python3
"""Generates the configuration console pages and their server actions.

Every page follows the same shape: a server component that checks the
permission, loads the option lists and the first page of rows, and hands both
to the shared client component. Every action file exports the six named
actions the console uses.

The generator only writes files that do not exist yet, so a page that has
been hand-tuned is never overwritten.
"""

import pathlib
import sys

APP = pathlib.Path(__file__).resolve().parents[1] / "app" / "(console)" / "settings" / "configuration"

# slug, resource export, action prefix, component name, permission, group
PAGES = [
    ("countries", "countries", "Country", "CountriesPage", "manage_countries", "Geography", "Countries"),
    ("country-configurations", "countryConfigurations", "CountryConfiguration", "CountryConfigurationsPage", "manage_countries", "Geography", "CountryConfigurations"),
    ("vehicle-types", "vehicleTypes", "VehicleType", "VehicleTypesPage", "manage_vehicle_catalog", "Vehicles", "VehicleTypes"),
    ("vehicle-makes", "vehicleMakes", "VehicleMake", "VehicleMakesPage", "manage_vehicle_catalog", "Vehicles", "VehicleMakes"),
    ("vehicle-models", "vehicleModels", "VehicleModel", "VehicleModelsPage", "manage_vehicle_catalog", "Vehicles", "VehicleModels"),
    ("vehicle-equipment", "vehicleEquipment", "VehicleEquipment", "VehicleEquipmentPage", "manage_vehicle_catalog", "Vehicles", "VehicleEquipment"),
    ("cargo-categories", "cargoCategories", "CargoCategory", "CargoCategoriesPage", "manage_cargo_catalog", "Cargo", "CargoCategories"),
    ("cargo-types", "cargoTypes", "CargoType", "CargoTypesPage", "manage_cargo_catalog", "Cargo", "CargoTypes"),
    ("cargo-restrictions", "cargoRestrictions", "CargoRestriction", "CargoRestrictionsPage", "manage_cargo_catalog", "Cargo", "CargoRestrictions"),
    ("cargo-packaging", "cargoPackaging", "CargoPackaging", "CargoPackagingPage", "manage_cargo_catalog", "Cargo", "CargoPackaging"),
    ("document-types", "documentTypes", "DocumentType", "DocumentTypesPage", "manage_document_types", "Verification", "DocumentTypes"),
    ("verification-checklists", "verificationChecklists", "VerificationChecklist", "VerificationChecklistsPage", "manage_document_types", "Verification", "VerificationChecklists"),
    ("prohibited-items", "prohibitedItems", "ProhibitedItem", "ProhibitedItemsPage", "manage_prohibited_items", "Support & Safety", "ProhibitedItems"),
    ("support-categories", "supportCategories", "SupportCategory", "SupportCategoriesPage", "manage_support", "Support & Safety", "SupportCategories"),
    ("notification-templates", "notificationTemplates", "NotificationTemplate", "NotificationTemplatesPage", "manage_notifications", "Communication", "NotificationTemplates"),
    ("localization-strings", "localizationStrings", "LocalizationString", "LocalizationStringsPage", "manage_localization", "Communication", "LocalizationStrings"),
    ("feature-flags", "featureFlags", "FeatureFlag", "FeatureFlagsPage", "manage_features", "Platform", "FeatureFlags"),
    ("cancellation-policies", "cancellationPolicies", "CancellationPolicy", "CancellationPoliciesPage", "manage_cancellation_policies", "Platform", "CancellationPolicies"),
    ("dispatch-rules", "dispatchRules", "DispatchRule", "DispatchRulesPage", "manage_dispatch", "Platform", "DispatchRules"),
    ("rating-categories", "ratingCategories", "RatingCategory", "RatingCategoriesPage", "manage_ratings", "Platform", "RatingCategories"),
    ("admin-roles", "adminRoles", "AdminRole", "AdminRolesPage", "manage_admins", "Administration", "AdminRoles"),
    ("permissions-catalog", "permissionsCatalog", "PermissionGrant", "PermissionsCatalogPage", "manage_admins", "Administration", "PermissionGrants"),
]

ACTIONS_TEMPLATE = """'use server';

import type {{ AuditQuery }} from '@/components/configuration/audit-history-button';
import {{
  configurationAuditHistory,
  configurationReferences,
  createConfigurationRecord,
  deactivateConfigurationRecord,
  deleteConfigurationRecord,
  listConfigurationRecords,
  updateConfigurationRecord,
}} from '@/lib/configuration/action-helpers';
import {{ {resource} }} from '@/lib/configuration/resources';
import type {{ ConfigFieldValues, ListFilters }} from '@/lib/configuration/types';

/** Lists the {resource_label} rows. */
export async function list{plural}(filters: ListFilters) {{
  return listConfigurationRecords({resource}, filters);
}}

/** Creates one {resource_label}. */
export async function create{prefix}(values: ConfigFieldValues) {{
  return createConfigurationRecord({resource}, values);
}}

/** Updates one {resource_label}. */
export async function update{prefix}(id: string, values: ConfigFieldValues) {{
  return updateConfigurationRecord({resource}, id, values);
}}

/** Deactivates one {resource_label}. */
export async function deactivate{prefix}(id: string, reason: string) {{
  return deactivateConfigurationRecord({resource}, id, reason);
}}

/** Removes one {resource_label}. */
export async function delete{prefix}(id: string) {{
  return deleteConfigurationRecord({resource}, id);
}}

/** Reads the audit trail of one {resource_label}. */
export async function get{prefix}AuditHistory(id: string, query: AuditQuery = {{}}) {{
  return configurationAuditHistory({resource}, id, query);
}}

/** Counts what still references one {resource_label}. */
export async function get{prefix}References(id: string) {{
  return configurationReferences({resource}, id);
}}
"""

PAGE_TEMPLATE = """import {{ ConfigurationClient }} from '@/components/configuration/configuration-client';
import {{ PageHeader }} from '@/components/page-header';
import {{ requireConfigurationPermission }} from '@/lib/configuration/guard';
import {{ loadOptionsFor }} from '@/lib/configuration/options';
import {{ {resource} }} from '@/lib/configuration/resources';
import type {{ ListFilters }} from '@/lib/configuration/types';
import {{ toView }} from '@/lib/configuration/view';
import {{ createClient }} from '@/lib/supabase/server';

import {{
  create{prefix},
  deactivate{prefix},
  delete{prefix},
  get{prefix}AuditHistory,
  get{prefix}References,
  list{plural},
  update{prefix},
}} from './actions';

export const dynamic = 'force-dynamic';

export default async function {component}() {{
  await requireConfigurationPermission('{permission}');

  const supabase = await createClient();
  const filters: ListFilters = {{ page: 1, pageSize: 25 }};
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, {resource}),
    list{plural}(filters),
  ]);

  return (
    <>
      <PageHeader title={{{resource}.pluralTitle}} description={{{resource}.description}} />
      <ConfigurationClient
        actions={{{{
          list: list{plural},
          create: create{prefix},
          update: update{prefix},
          deactivate: deactivate{prefix},
          remove: delete{prefix},
          audit: get{prefix}AuditHistory,
          references: get{prefix}References,
        }}}}
        countries={{options.countries ?? []}}
        initialPage={{initial.page}}
        initialRows={{initial.rows ?? []}}
        initialTotal={{initial.total ?? 0}}
        options={{options}}
        view={{toView({resource})}}
      />
    </>
  );
}}
"""


def main() -> int:
    written: list[str] = []
    for slug, resource, prefix, component, permission, group, plural in PAGES:
        folder = APP / slug
        folder.mkdir(parents=True, exist_ok=True)

        actions_path = folder / "actions.ts"
        if not actions_path.exists():
            actions_path.write_text(
                ACTIONS_TEMPLATE.format(
                    resource=resource,
                    prefix=prefix,
                    plural=plural,
                    resource_label=resource.replace("Resource", "").replace("Catalog", "grant"),
                )
            )
            written.append(str(actions_path))

        page_path = folder / "page.tsx"
        if not page_path.exists():
            page_path.write_text(
                PAGE_TEMPLATE.format(
                    resource=resource,
                    prefix=prefix,
                    plural=plural,
                    component=component,
                    permission=permission,
                )
            )
            written.append(str(page_path))

    for path in written:
        print(f"wrote {path}")
    print(f"{len(written)} files written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
