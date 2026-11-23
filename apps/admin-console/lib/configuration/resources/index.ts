/**
 * The twenty-one configuration tables, and the navigation that lists them.
 *
 * The order of `CONFIGURATION_GROUPS` is the order the operator sees in the
 * console sidebar and in the Configuration section's own sub-navigation.
 */

import type { ConfigResource } from '../types';
import {
  cargoCategoriesResource,
  cargoPackagingResource,
  cargoRestrictionsResource,
  cargoTypesResource,
} from './cargo';
import { notificationTemplatesResource, localizationStringsResource } from './communication';
import { adminRolesResource, permissionsCatalogResource } from './administration';
import {
  addressesResource,
  citiesResource,
  countriesResource,
  countryConfigurationsResource,
  neighborhoodsResource,
  regionsResource,
  serviceZonesResource,
} from './geography';
import {
  cancellationPoliciesResource,
  dispatchRulesResource,
  featureFlagsResource,
  ratingCategoriesResource,
} from './platform';
import { documentTypesResource, verificationChecklistsResource } from './verification';
import { prohibitedItemsResource, supportCategoriesResource } from './support';
import {
  vehicleEquipmentResource,
  vehicleMakesResource,
  vehicleModelsResource,
  vehicleTypesResource,
} from './vehicles';

export * from './administration';
export * from './cargo';
export * from './communication';
export * from './geography';
export * from './platform';
export * from './support';
export * from './verification';
export * from './vehicles';

export const vehicleTypes = vehicleTypesResource;
export const vehicleMakes = vehicleMakesResource;
export const vehicleModels = vehicleModelsResource;
export const vehicleEquipment = vehicleEquipmentResource;
export const cargoCategories = cargoCategoriesResource;
export const cargoTypes = cargoTypesResource;
export const cargoRestrictions = cargoRestrictionsResource;
export const cargoPackaging = cargoPackagingResource;
export const documentTypes = documentTypesResource;
export const verificationChecklists = verificationChecklistsResource;
export const prohibitedItems = prohibitedItemsResource;
export const supportCategories = supportCategoriesResource;
export const notificationTemplates = notificationTemplatesResource;
export const localizationStrings = localizationStringsResource;
export const featureFlags = featureFlagsResource;
export const cancellationPolicies = cancellationPoliciesResource;
export const dispatchRules = dispatchRulesResource;
export const ratingCategories = ratingCategoriesResource;
export const adminRoles = adminRolesResource;
export const permissionsCatalog = permissionsCatalogResource;
export const countries = countriesResource;
export const countryConfigurations = countryConfigurationsResource;
export const regions = regionsResource;
export const cities = citiesResource;
export const serviceZones = serviceZonesResource;
export const neighborhoods = neighborhoodsResource;
export const addresses = addressesResource;

/** Every configuration resource, keyed by the slug of its page. */
export const CONFIGURATION_RESOURCES: Record<string, ConfigResource> = {
  'vehicle-types': vehicleTypes,
  'vehicle-makes': vehicleMakes,
  'vehicle-models': vehicleModels,
  'vehicle-equipment': vehicleEquipment,
  'cargo-categories': cargoCategories,
  'cargo-types': cargoTypes,
  'cargo-restrictions': cargoRestrictions,
  'cargo-packaging': cargoPackaging,
  'document-types': documentTypes,
  'verification-checklists': verificationChecklists,
  'prohibited-items': prohibitedItems,
  'support-categories': supportCategories,
  'notification-templates': notificationTemplates,
  'localization-strings': localizationStrings,
  'feature-flags': featureFlags,
  'cancellation-policies': cancellationPolicies,
  'dispatch-rules': dispatchRules,
  'rating-categories': ratingCategories,
  'admin-roles': adminRoles,
  'permissions-catalog': permissionsCatalog,
  countries: countries,
  'country-configurations': countryConfigurations,
  regions: regions,
  cities: cities,
  'service-zones': serviceZones,
  neighborhoods: neighborhoods,
  addresses: addresses,
};

export type ConfigNavItem = {
  label: string;
  slug: string;
  href: string;
  permission: string;
  children?: ConfigNavItem[];
};

export type ConfigNavGroup = {
  label: string;
  items: ConfigNavItem[];
};

function item(slug: string, label: string, resource: ConfigResource): ConfigNavItem {
  return {
    label,
    slug,
    href: `/settings/configuration/${slug}`,
    permission: resource.permission,
  };
}

/**
 * The Configuration navigation.
 *
 * "Makes & Models" is a collapsible pair rather than one leaf, because the
 * two tables have their own pages: a make cannot be edited on the models
 * page and a model cannot be edited on the makes page.
 */
export const CONFIGURATION_GROUPS: ConfigNavGroup[] = [
  {
    label: 'Geography',
    items: [
      item('countries', 'Countries', countries),
      item('regions', 'Regions', regions),
      item('cities', 'Cities', cities),
      item('service-zones', 'Service Zones', serviceZones),
      item('neighborhoods', 'Neighbourhoods', neighborhoods),
      item('addresses', 'Addresses', addresses),
    ],
  },
  {
    label: 'Vehicles',
    items: [
      item('vehicle-types', 'Vehicle Types', vehicleTypes),
      {
        label: 'Makes & Models',
        slug: 'makes-and-models',
        href: '/settings/configuration/vehicle-makes',
        permission: 'manage_vehicle_catalog',
        children: [
          item('vehicle-makes', 'Vehicle Makes', vehicleMakes),
          item('vehicle-models', 'Vehicle Models', vehicleModels),
        ],
      },
      item('vehicle-equipment', 'Equipment', vehicleEquipment),
    ],
  },
  {
    label: 'Cargo',
    items: [
      item('cargo-categories', 'Categories', cargoCategories),
      item('cargo-types', 'Cargo Types', cargoTypes),
      item('cargo-restrictions', 'Restrictions', cargoRestrictions),
      item('cargo-packaging', 'Packaging', cargoPackaging),
    ],
  },
  {
    label: 'Verification',
    items: [
      item('document-types', 'Document Types', documentTypes),
      item('verification-checklists', 'Checklists', verificationChecklists),
    ],
  },
  {
    label: 'Support & Safety',
    items: [
      item('prohibited-items', 'Prohibited Items', prohibitedItems),
      item('support-categories', 'Support Categories', supportCategories),
    ],
  },
  {
    label: 'Communication',
    items: [
      item('notification-templates', 'Notification Templates', notificationTemplates),
    ],
  },
  {
    label: 'Platform',
    items: [
      item('cancellation-policies', 'Cancellation Policies', cancellationPolicies),
      item('dispatch-rules', 'Dispatch Rules', dispatchRules),
      item('rating-categories', 'Rating Categories', ratingCategories),
    ],
  },
  {
    label: 'Administration',
    items: [
      item('admin-roles', 'Admin Roles', adminRoles),
      item('permissions-catalog', 'Permissions Catalog', permissionsCatalog),
    ],
  },
];

/**
 * Every permission that unlocks part of the Configuration section.
 *
 * The sidebar shows the section when the caller holds the umbrella
 * 'manage_configuration' or any one of these.
 */
export const CONFIGURATION_PERMISSIONS = [
  'manage_configuration',
  'manage_vehicle_catalog',
  'manage_cargo_catalog',
  'manage_document_types',
  'manage_support',
  'manage_prohibited_items',
  'manage_notifications',
  'manage_localization',
  'manage_features',
  'manage_cancellation_policies',
  'manage_dispatch',
  'manage_ratings',
  'manage_countries',
  'manage_geography',
  'manage_admins',
] as const;

/**
 * The permissions the umbrella 'manage_configuration' expands to.
 *
 * 'manage_admins' is deliberately absent: it grants the ability to mint new
 * admin roles, which is a different class of change from editing a
 * catalogue. If the umbrella covered it, an operations administrator who
 * held the umbrella could grant themselves super_admin and escalate.
 *
 * This list mirrors public.config_permission_keys() in migration 0132.
 */
export const CONFIGURATION_UMBRELLA_PERMISSIONS = [
  'manage_vehicle_catalog',
  'manage_cargo_catalog',
  'manage_document_types',
  'manage_support',
  'manage_prohibited_items',
  'manage_notifications',
  'manage_localization',
  'manage_features',
  'manage_cancellation_policies',
  'manage_dispatch',
  'manage_ratings',
  'manage_countries',
  'manage_geography',
] as const;

/** The slugs of every configuration page, in navigation order. */
export const CONFIGURATION_SLUGS = Object.keys(CONFIGURATION_RESOURCES);

/** The page slug of every configuration table. */
export const CONFIGURATION_SLUG_BY_TABLE: Record<string, string> = {
  vehicle_types: 'vehicle-types',
  vehicle_makes: 'vehicle-makes',
  vehicle_models: 'vehicle-models',
  vehicle_equipment_catalog: 'vehicle-equipment',
  cargo_categories: 'cargo-categories',
  cargo_types: 'cargo-types',
  cargo_restrictions: 'cargo-restrictions',
  cargo_packaging_options: 'cargo-packaging',
  document_types: 'document-types',
  verification_checklist_templates: 'verification-checklists',
  prohibited_items: 'prohibited-items',
  support_categories: 'support-categories',
  notification_templates: 'notification-templates',
  localization_strings: 'localization-strings',
  feature_flags: 'feature-flags',
  cancellation_policies: 'cancellation-policies',
  dispatch_rules: 'dispatch-rules',
  rating_categories: 'rating-categories',
  admin_roles: 'admin-roles',
  admin_role_permissions: 'permissions-catalog',
  countries: 'countries',
  country_configurations: 'country-configurations',
  regions: 'regions',
  cities: 'cities',
  service_zones: 'service-zones',
  neighborhoods: 'neighborhoods',
  addresses: 'addresses',
};
