/**
 * Group 6 — Platform configuration.
 *
 * feature_flags, cancellation_policies, dispatch_rules and rating_categories.
 */

import type { ConfigResource } from '../types';

export const featureFlagsResource: ConfigResource = {
  table: 'feature_flags',
  singular: 'feature flag',
  singularTitle: 'Feature Flag',
  pluralTitle: 'Feature Flags',
  description:
    'Scoped rollout switches. The most specific scope wins: a flag for one profile beats a flag for a city, which beats a flag for a country, which beats the global flag.',
  permission: 'manage_features',
  group: 'Platform',
  countryScoped: true,
  // feature_flags has no is_active column: a flag is either enabled or it is
  // not, so removing one is a hard delete.
  hardDelete: true,
  selectSpec:
    'id, flag_key, country_id, city_id, profile_id, is_enabled, rollout_percentage, description, created_at, updated_at, countries(name, iso_code), cities(name), profiles(id, full_name, display_name, email)',
  uniqueColumns: [
    {
      columns: ['flag_key', 'country_id', 'city_id', 'profile_id'],
      label: 'flag in this scope',
    },
  ],
  columns: [
    { key: 'flag_key', label: 'Flag', kind: 'code', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'city_name', label: 'City' },
    { key: 'profile_name', label: 'Profile' },
    { key: 'is_enabled', label: 'Enabled', kind: 'boolean' },
    { key: 'rollout_percentage', label: 'Rollout %', kind: 'number' },
  ],
  searchColumns: ['flag_key', 'description'],
  fields: [
    {
      name: 'flag_key',
      label: 'Flag key',
      type: 'text',
      required: true,
      placeholder: 'live_tracking_v2',
      validate: (value) =>
        /^[a-z0-9_]+$/.test(String(value ?? ''))
          ? null
          : 'Use lower case letters, digits and underscores only.',
    },
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      optionsKey: 'countries',
      help: 'Leave empty for a global flag.',
    },
    {
      name: 'city_id',
      label: 'City',
      type: 'select',
      optionsKey: 'cities',
      dependsOn: { field: 'country_id', notEquals: '' },
      help: 'Only available once a country is set.',
    },
    {
      name: 'profile_id',
      label: 'Profile',
      type: 'select',
      optionsKey: 'profiles',
      dependsOn: { field: 'country_id', notEquals: '' },
      help: 'Set a profile to beta test with a single account.',
    },
    { name: 'is_enabled', label: 'Enabled', type: 'checkbox', defaultValue: false },
    {
      name: 'rollout_percentage',
      label: 'Rollout percentage',
      type: 'number',
      defaultValue: 0,
      min: 0,
      max: 100,
    },
    { name: 'description', label: 'Description', type: 'textarea' },
  ],
  defaultSort: { column: 'flag_key', ascending: true },
};

export const cancellationPoliciesResource: ConfigResource = {
  table: 'cancellation_policies',
  singular: 'cancellation policy',
  singularTitle: 'Cancellation Policy',
  pluralTitle: 'Cancellation Policies',
  description:
    'The fee charged when a booking is cancelled. Existing jobs keep the policy that was applied to them; new jobs pick up whichever policy is active.',
  permission: 'manage_cancellation_policies',
  group: 'Platform',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, name, description, applies_to_role, free_cancellation_window_minutes, fee_type, fee_value, currency_code, fee_tiers, is_active, created_at, updated_at, countries(name, iso_code)',
  columns: [
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'applies_to_role', label: 'Applies to' },
    { key: 'free_cancellation_window_minutes', label: 'Free window (min)', kind: 'number' },
    { key: 'fee_type', label: 'Fee type' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'description'],
  fields: [
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      required: true,
      optionsKey: 'countries',
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'applies_to_role',
      label: 'Applies to',
      type: 'select',
      required: true,
      defaultValue: 'customer',
      options: [
        { value: 'customer', label: 'Customer' },
        { value: 'driver', label: 'Driver' },
      ],
    },
    {
      name: 'free_cancellation_window_minutes',
      label: 'Free cancellation window (minutes)',
      type: 'number',
      defaultValue: 5,
      min: 0,
    },
    {
      name: 'fee_type',
      label: 'Fee type',
      type: 'select',
      required: true,
      defaultValue: 'flat',
      options: [
        { value: 'flat', label: 'Flat fee' },
        { value: 'percentage_of_quote', label: 'Percentage of the quote' },
        { value: 'tiered', label: 'Tiered' },
      ],
    },
    {
      name: 'fee_value',
      label: 'Fee value',
      type: 'number',
      defaultValue: 0,
      min: 0,
      help: 'A flat amount in the policy currency, or a percentage when the fee type is a percentage.',
    },
    {
      name: 'currency_code',
      label: 'Currency',
      type: 'select',
      optionsKey: 'currencies',
      dependsOn: { field: 'fee_type', equals: 'flat' },
      help: 'Required for a flat fee.',
    },
    {
      name: 'fee_tiers',
      label: 'Fee tiers',
      type: 'json',
      dependsOn: { field: 'fee_type', equals: 'tiered' },
      placeholder:
        '[{ "minutes_before_pickup": 120, "fee": 5000 }, { "minutes_before_pickup": 30, "fee": 10000 }]',
      help: 'An array of tiers. Each tier needs minutes_before_pickup and fee.',
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  crossRules: [
    {
      field: 'currency_code',
      type: 'required_when',
      against: 'fee_type',
      equals: 'flat',
      message: 'A flat fee needs a currency.',
    },
    {
      field: 'fee_tiers',
      type: 'required_when',
      against: 'fee_type',
      equals: 'tiered',
      message: 'A tiered fee needs at least one tier.',
    },
  ],
  validate: (values): Record<string, string> => {
    if (values.fee_type !== 'percentage_of_quote') return {};
    if (Number(values.fee_value ?? 0) <= 100) return {};
    return { fee_value: 'A percentage fee cannot be more than 100.' };
  },
  defaultSort: { column: 'name', ascending: true },
  special: 'cancellation-calculator',
};

export const dispatchRulesResource: ConfigResource = {
  table: 'dispatch_rules',
  singular: 'dispatch rule',
  singularTitle: 'Dispatch Rule',
  pluralTitle: 'Dispatch Rules',
  description:
    'How far the matcher searches, how long an offer stays open and how many offers go out at once. The most specific active rule wins: vehicle type, then city, then country, then the global rule.',
  permission: 'manage_dispatch',
  group: 'Platform',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, city_id, vehicle_type_id, max_search_radius_km, offer_timeout_seconds, max_concurrent_offers, reassign_after_seconds, minimum_acceptance_rate, min_driver_rating, is_active, created_at, updated_at, countries(name, iso_code), cities(name), vehicle_types(name)',
  columns: [
    { key: 'country_name', label: 'Country' },
    { key: 'city_name', label: 'City' },
    { key: 'vehicle_type_name', label: 'Vehicle type' },
    { key: 'max_search_radius_km', label: 'Radius (km)', kind: 'number' },
    { key: 'offer_timeout_seconds', label: 'Offer timeout (s)', kind: 'number' },
    { key: 'max_concurrent_offers', label: 'Max offers', kind: 'number' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: [],
  fields: [
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      optionsKey: 'countries',
      help: 'Leave empty for a rule that applies everywhere.',
    },
    {
      name: 'city_id',
      label: 'City',
      type: 'select',
      optionsKey: 'cities',
      dependsOn: { field: 'country_id', notEquals: '' },
      help: 'Only available once a country is set.',
    },
    {
      name: 'vehicle_type_id',
      label: 'Vehicle type',
      type: 'select',
      optionsKey: 'vehicle_types',
      help: 'Leave empty to apply the rule to every vehicle type.',
    },
    {
      name: 'max_search_radius_km',
      label: 'Maximum search radius (km)',
      type: 'number',
      defaultValue: 10,
      min: 1,
      max: 500,
      step: 0.5,
    },
    {
      name: 'offer_timeout_seconds',
      label: 'Offer timeout (seconds)',
      type: 'number',
      defaultValue: 30,
      min: 5,
      max: 600,
    },
    {
      name: 'max_concurrent_offers',
      label: 'Maximum concurrent offers',
      type: 'number',
      defaultValue: 1,
      min: 1,
      max: 20,
    },
    {
      name: 'reassign_after_seconds',
      label: 'Reassign after (seconds)',
      type: 'number',
      defaultValue: 60,
      min: 0,
      max: 3600,
    },
    {
      name: 'minimum_acceptance_rate',
      label: 'Minimum acceptance rate',
      type: 'number',
      defaultValue: 0.5,
      min: 0,
      max: 1,
      step: 0.01,
      help: 'A share between 0 and 1. 0.5 means 50%.',
    },
    {
      name: 'min_driver_rating',
      label: 'Minimum driver rating',
      type: 'number',
      defaultValue: 4,
      min: 0,
      max: 5,
      step: 0.1,
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'country_name', ascending: true },
  special: 'dispatch-resolution',
};

export const ratingCategoriesResource: ConfigResource = {
  table: 'rating_categories',
  singular: 'rating category',
  singularTitle: 'Rating Category',
  pluralTitle: 'Rating Categories',
  description:
    'The dimensions customers and drivers rate each other on. The role is the rater, not the rated.',
  permission: 'manage_ratings',
  group: 'Platform',
  softDelete: true,
  selectSpec:
    'id, code, name, description, applies_to_role, display_order, is_active, created_at, updated_at',
  uniqueColumns: [{ columns: ['code'], label: 'code' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'applies_to_role', label: 'Rated by' },
    { key: 'display_order', label: 'Order', kind: 'number' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['code', 'name', 'description'],
  fields: [
    {
      name: 'code',
      label: 'Code',
      type: 'text',
      required: true,
      validate: (value) =>
        /^[a-z][a-z0-9_]{1,63}$/.test(String(value ?? ''))
          ? null
          : 'Use a lower case letter, then lower case letters, digits or underscores.',
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'applies_to_role',
      label: 'Rated by',
      type: 'select',
      required: true,
      defaultValue: 'customer',
      options: [
        { value: 'customer', label: 'Customer' },
        { value: 'driver', label: 'Driver' },
      ],
    },
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'display_order', ascending: true },
};
