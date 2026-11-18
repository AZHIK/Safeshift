/**
 * Group 8 — Geography.
 *
 * countries and country_configurations. The root of the scope hierarchy:
 * twenty-eight tables carry a country_id, and every country-scoped
 * configuration row in the console points at one of these rows.
 *
 * A country is retired by clearing is_active, never by removing the row,
 * because the market's history (jobs, quotes, payouts) hangs off the id.
 */

import type { ConfigResource } from '../types';

export const countriesResource: ConfigResource = {
  table: 'countries',
  singular: 'country',
  singularTitle: 'Country',
  pluralTitle: 'Countries',
  description:
    'The markets the platform operates in. Every other configuration row is scoped to a country, and a country that is switched off disappears from the booking flow.',
  permission: 'manage_countries',
  group: 'Geography',
  // A country is the scope, so it is not itself scoped to one.
  countryScoped: false,
  softDelete: true,
  selectSpec:
    'id, iso_code, name, default_currency_id, default_timezone, default_language_id, regulatory_framework, tax_registration_required, phone_code, is_active, launched_at, created_at, updated_at, currency:currencies(code, name, symbol), language:languages(code, name)',
  uniqueColumns: [{ columns: ['iso_code'], label: 'ISO code' }],
  columns: [
    { key: 'name', label: 'Country', sortable: true },
    { key: 'iso_code', label: 'ISO', kind: 'code', sortable: true },
    { key: 'currency_name', label: 'Currency' },
    { key: 'language_name', label: 'Language' },
    { key: 'phone_code', label: 'Phone code' },
    { key: 'default_timezone', label: 'Time zone' },
    { key: 'regulatory_framework', label: 'Regulator' },
    { key: 'tax_registration_required', label: 'Tax ID', kind: 'boolean' },
    { key: 'launched_at', label: 'Launched', kind: 'date' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'iso_code', 'regulatory_framework'],
  // Sends the operator to the settings of this country.
  rowAction: {
    label: 'Settings',
    href: '/settings/configuration/country-configurations?country={id}',
  },
  references: [
    { key: 'cities', label: 'active cities', blocking: true },
    { key: 'regions', label: 'active regions', blocking: true },
    { key: 'vehicles', label: 'active vehicles', blocking: true },
    { key: 'drivers', label: 'drivers', blocking: true },
    { key: 'pricing_plans', label: 'active pricing plans', blocking: true },
    { key: 'tax_rates', label: 'active tax rates', blocking: true },
    { key: 'payment_providers', label: 'active payment providers', blocking: true },
    { key: 'business_accounts', label: 'active business accounts', blocking: true },
    { key: 'fleets', label: 'active fleets', blocking: true },
    { key: 'configurations', label: 'active configurations', blocking: true },
  ],
  fields: [
    {
      name: 'iso_code',
      label: 'Country',
      type: 'select',
      required: true,
      optionsKey: 'catalogue_countries',
      help: 'The countries the platform supports. Choosing one fills the currency, the language, the phone code and the time zone below.',
      validate: (value) =>
        /^[A-Z]{2}$/.test(String(value ?? '').trim())
          ? null
          : 'Choose a country from the catalogue.',
    },
    {
      name: 'name',
      label: 'Country name',
      type: 'text',
      required: true,
      autofillFrom: 'name',
    },
    {
      name: 'default_currency_id',
      label: 'Default currency',
      type: 'select',
      optionsKey: 'currency_ids',
      autofillFrom: 'currencyId',
      help: 'The currency the market settles in. Filled in from the country catalogue.',
    },
    {
      name: 'default_language_id',
      label: 'Default language',
      type: 'select',
      optionsKey: 'languages',
      autofillFrom: 'languageId',
      help: 'The language the customer and driver apps start in. Filled in from the country catalogue.',
    },
    {
      name: 'phone_code',
      label: 'Phone code',
      type: 'text',
      autofillFrom: 'phoneCode',
      placeholder: '+255',
      help: "The dialling code the country's phone numbers use. Filled in from the country catalogue.",
    },
    {
      name: 'default_timezone',
      label: 'Time zone',
      type: 'text',
      required: true,
      autofillFrom: 'timeZone',
      placeholder: 'Africa/Dar_es_Salaam',
      help: 'The IANA time zone the market runs in. Filled in from the country catalogue.',
    },
    {
      name: 'regulatory_framework',
      label: 'Regulatory framework',
      type: 'text',
      placeholder: 'NTSA',
      help: 'The transport regulator for this country. Stored as data, never hard-coded.',
    },
    {
      name: 'tax_registration_required',
      label: 'Tax registration required',
      type: 'checkbox',
      defaultValue: false,
      help: 'When set, a business in this country must give a tax registration number.',
    },
    { name: 'launched_at', label: 'Launched on', type: 'date' },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

/**
 * The settings of one country, one row per setting.
 *
 * These used to live in a single jsonb column on public.countries, which
 * could not be searched, constrained, indexed or audited column by column.
 * A row here is one setting of one country, so the operator can find it,
 * filter it, and give it its own description.
 */
export const countryConfigurationsResource: ConfigResource = {
  table: 'country_configurations',
  singular: 'country configuration',
  singularTitle: 'Country Configuration',
  pluralTitle: 'Country Configurations',
  description:
    'The settings of a country, one row per setting: payment providers, KYC rules, document requirements, feature defaults.',
  permission: 'manage_countries',
  group: 'Geography',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, config_key, config_value, description, is_active, created_at, updated_at, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'config_key'], label: 'key in this country' }],
  columns: [
    { key: 'config_key', label: 'Setting', kind: 'code', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'config_value', label: 'Value', kind: 'json' },
    { key: 'description', label: 'Description' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['config_key', 'description'],
  fields: [
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      required: true,
      optionsKey: 'countries',
    },
    {
      name: 'config_key',
      label: 'Setting',
      type: 'text',
      required: true,
      placeholder: 'payment_providers',
      help: 'The name of the setting, in lower case with underscores.',
      validate: (value) =>
        /^[a-z0-9_]+$/.test(String(value ?? '').trim())
          ? null
          : 'Use lower case letters, digits and underscores only.',
    },
    {
      name: 'config_value',
      label: 'Value',
      type: 'json',
      required: true,
      defaultValue: {},
      help: 'The value of the setting, as JSON. Its shape depends on the key.',
      validate: (value) =>
        typeof value === 'string' && value.trim() !== ''
          ? null
          : 'Enter the value as JSON, e.g. ["mpesa"] or true.',
    },
    {
      name: 'description',
      label: 'Description',
      type: 'textarea',
      help: 'What this setting does, and who reads it.',
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'config_key', ascending: true },
};
