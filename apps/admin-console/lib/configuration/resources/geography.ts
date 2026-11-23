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

import type { AugmentContext, ConfigResource } from '../types';

const GEOGRAPHY_WRITE_RPC = 'admin_write_geography';
const GEOGRAPHY_WKT_RPC = 'admin_geography_wkt';
const GEOGRAPHY_REFERENCES_RPC = 'admin_geography_reference_counts';

/** Validates the WKT an operator enters for a geography column. */
function wktField(label: string, shapes: string[]) {
  return {
    label,
    type: 'geography' as const,
    required: true,
    placeholder: 'POLYGON((39.24 -6.86, 39.31 -6.86, 39.31 -6.78, 39.24 -6.86))',
    help: `Well-known text for a ${shapes.join(' or ')} in longitude/latitude order.`,
    validate: (value: unknown) => {
      const text = String(value ?? '').trim();
      if (!text) return null;
      const shape = text.split('(')[0].trim().toUpperCase();
      return shapes.some((allowed) => shape.startsWith(allowed))
        ? null
        : `Enter a ${shapes.join(' or ')} in WKT form.`;
    },
  };
}

/** Fills WKT fields on rows loaded from a PostGIS geography table. */
async function withGeometry(
  rows: Record<string, unknown>[],
  ctx: AugmentContext,
  table: string,
): Promise<void> {
  if (rows.length === 0) return;
  const ids = rows.map((row) => String(row.id)).filter(Boolean);
  const { data, error } = await ctx.client.rpc(GEOGRAPHY_WKT_RPC, {
    p_table: table,
    p_ids: ids,
  });
  if (error || !data) return;
  const byId = new Map(
    (data as { id: string; boundary: string | null; centroid: string | null; location: string | null }[])
      .map((entry) => [String(entry.id), entry]),
  );
  for (const row of rows) {
    const geometry = byId.get(String(row.id));
    if (!geometry) continue;
    row.boundary = geometry.boundary;
    row.centroid = geometry.centroid;
    row.location = geometry.location;
  }
}

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
      label: 'ISO country code',
      type: 'text',
      required: true,
      placeholder: 'TZ',
      help: 'Enter the two-letter ISO code for the country you are adding to the database.',
      validate: (value) =>
        /^[A-Z]{2}$/.test(String(value ?? '').trim())
          ? null
          : 'Enter a two-letter uppercase ISO code.',
    },
    {
      name: 'name',
      label: 'Country name',
      type: 'text',
      required: true,
    },
    {
      name: 'default_currency_id',
      label: 'Default currency',
      type: 'select',
      optionsKey: 'currency_ids',
      help: 'The currency the market settles in.',
    },
    {
      name: 'default_language_id',
      label: 'Default language',
      type: 'select',
      optionsKey: 'languages',
      help: 'The language the customer and driver apps start in.',
    },
    {
      name: 'phone_code',
      label: 'Phone code',
      type: 'text',
      placeholder: '+255',
      help: "The dialling code the country's phone numbers use.",
    },
    {
      name: 'default_timezone',
      label: 'Time zone',
      type: 'text',
      required: true,
      placeholder: 'Africa/Dar_es_Salaam',
      help: 'The IANA time zone the market runs in.',
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

/**
 * The geography hierarchy below the country: a region holds cities, a city
 * holds service zones and neighbourhoods, and neighbourhoods hold addresses.
 * These are the rows the quote engine reads when it decides whether a pickup
 * is inside the operating area, so they must be editable from the console.
 *
 * Geometry columns are edited as WKT text and written through a database RPC
 * that converts them to PostGIS geography values.
 */
export const regionsResource: ConfigResource = {
  table: 'regions',
  singular: 'region',
  singularTitle: 'Region',
  pluralTitle: 'Regions',
  description: 'The administrative regions inside a country. Cities belong to one region.',
  permission: 'manage_geography',
  group: 'Geography',
  countryScoped: true,
  softDelete: true,
  writeRpc: GEOGRAPHY_WRITE_RPC,
  referenceCountsRpc: GEOGRAPHY_REFERENCES_RPC,
  selectSpec: 'id, country_id, name, code, is_active, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'name'], label: 'name in this country' }],
  columns: [
    { key: 'name', label: 'Region', sortable: true },
    { key: 'code', label: 'Code', kind: 'code' },
    { key: 'country_name', label: 'Country' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'code'],
  references: [{ key: 'cities', label: 'active cities', blocking: true }],
  fields: [
    { name: 'country_id', label: 'Country', type: 'select', required: true, optionsKey: 'countries' },
    { name: 'name', label: 'Region name', type: 'text', required: true },
    { name: 'code', label: 'Code', type: 'text', placeholder: 'DSM' },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

export const citiesResource: ConfigResource = {
  table: 'cities',
  singular: 'city',
  singularTitle: 'City',
  pluralTitle: 'Cities',
  description:
    'Cities define the service footprint. A pickup must fall inside an active city boundary to receive a quote.',
  permission: 'manage_geography',
  group: 'Geography',
  countryScoped: true,
  softDelete: true,
  writeRpc: GEOGRAPHY_WRITE_RPC,
  referenceCountsRpc: GEOGRAPHY_REFERENCES_RPC,
  selectSpec:
    'id, country_id, region_id, name, timezone, latitude, longitude, is_active, launched_at, config, countries(name, iso_code), regions(name)',
  uniqueColumns: [{ columns: ['region_id', 'name'], label: 'name in this region' }],
  columns: [
    { key: 'name', label: 'City', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'region_name', label: 'Region' },
    { key: 'timezone', label: 'Time zone' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'timezone'],
  references: [
    { key: 'service_zones', label: 'active service zones', blocking: true },
    { key: 'neighborhoods', label: 'active neighbourhoods', blocking: true },
    { key: 'addresses', label: 'addresses', blocking: true },
  ],
  augment: (rows, ctx) => withGeometry(rows, ctx, 'cities'),
  augmentRecord: (row, ctx) => withGeometry([row], ctx, 'cities'),
  fields: [
    { name: 'country_id', label: 'Country', type: 'select', required: true, optionsKey: 'countries' },
    { name: 'region_id', label: 'Region', type: 'select', required: true, optionsKey: 'regions' },
    { name: 'name', label: 'City name', type: 'text', required: true },
    {
      name: 'timezone',
      label: 'Time zone',
      type: 'text',
      required: true,
      placeholder: 'Africa/Dar_es_Salaam',
    },
    { name: 'latitude', label: 'Latitude', type: 'number', step: 0.0000001 },
    { name: 'longitude', label: 'Longitude', type: 'number', step: 0.0000001 },
    {
      ...wktField('Boundary (WKT)', ['POLYGON']),
      name: 'boundary',
      required: false,
      help: 'Optional WKT POLYGON. When set, only pickups inside it get a quote. Leave blank to use the city centre only.',
    },
    { name: 'config', label: 'Configuration', type: 'json', defaultValue: {} },
    { name: 'launched_at', label: 'Launched on', type: 'date' },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

export const serviceZonesResource: ConfigResource = {
  table: 'service_zones',
  singular: 'service zone',
  singularTitle: 'Service Zone',
  pluralTitle: 'Service Zones',
  description: 'Operating and pricing polygons inside a city, used for dispatch and zone surcharges.',
  permission: 'manage_geography',
  group: 'Geography',
  softDelete: true,
  writeRpc: GEOGRAPHY_WRITE_RPC,
  referenceCountsRpc: GEOGRAPHY_REFERENCES_RPC,
  selectSpec: 'id, city_id, name, zone_type, is_active, metadata, cities(name)',
  uniqueColumns: [{ columns: ['city_id', 'name'], label: 'name in this city' }],
  columns: [
    { key: 'name', label: 'Zone', sortable: true },
    { key: 'city_name', label: 'City' },
    { key: 'zone_type', label: 'Type', kind: 'code' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'zone_type'],
  references: [
    { key: 'neighborhoods', label: 'active neighbourhoods', blocking: true },
    { key: 'addresses', label: 'addresses', blocking: true },
    { key: 'zone_pricing_overrides', label: 'pricing overrides', blocking: true },
  ],
  augment: (rows, ctx) => withGeometry(rows, ctx, 'service_zones'),
  augmentRecord: (row, ctx) => withGeometry([row], ctx, 'service_zones'),
  fields: [
    { name: 'city_id', label: 'City', type: 'select', required: true, optionsKey: 'cities' },
    { name: 'name', label: 'Zone name', type: 'text', required: true },
    {
      name: 'zone_type',
      label: 'Zone type',
      type: 'select',
      required: true,
      defaultValue: 'operating_area',
      options: [
        { value: 'operating_area', label: 'Operating area' },
        { value: 'pricing_zone', label: 'Pricing zone' },
        { value: 'surge_zone', label: 'Surge zone' },
        { value: 'restricted_zone', label: 'Restricted zone' },
        { value: 'priority_zone', label: 'Priority zone' },
      ],
    },
    { ...wktField('Boundary (WKT)', ['POLYGON']), name: 'boundary' },
    { ...wktField('Centroid (WKT)', ['POINT']), name: 'centroid' },
    { name: 'metadata', label: 'Metadata', type: 'json', defaultValue: {} },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

export const neighborhoodsResource: ConfigResource = {
  table: 'neighborhoods',
  singular: 'neighbourhood',
  singularTitle: 'Neighbourhood',
  pluralTitle: 'Neighbourhoods',
  description: 'Named neighbourhoods inside a city and service zone, used for place suggestions.',
  permission: 'manage_geography',
  group: 'Geography',
  softDelete: true,
  writeRpc: GEOGRAPHY_WRITE_RPC,
  referenceCountsRpc: GEOGRAPHY_REFERENCES_RPC,
  selectSpec:
    'id, city_id, service_zone_id, name, is_active, cities(name), service_zones(name)',
  uniqueColumns: [{ columns: ['city_id', 'name'], label: 'name in this city' }],
  columns: [
    { key: 'name', label: 'Neighbourhood', sortable: true },
    { key: 'city_name', label: 'City' },
    { key: 'service_zone_name', label: 'Service zone' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name'],
  references: [{ key: 'addresses', label: 'addresses', blocking: true }],
  augment: (rows, ctx) => withGeometry(rows, ctx, 'neighborhoods'),
  augmentRecord: (row, ctx) => withGeometry([row], ctx, 'neighborhoods'),
  fields: [
    { name: 'city_id', label: 'City', type: 'select', required: true, optionsKey: 'cities' },
    {
      name: 'service_zone_id',
      label: 'Service zone',
      type: 'select',
      required: true,
      optionsKey: 'service_zones',
    },
    { name: 'name', label: 'Neighbourhood name', type: 'text', required: true },
    { ...wktField('Centroid (WKT)', ['POINT']), name: 'centroid', required: false },
    { ...wktField('Boundary (WKT)', ['POLYGON']), name: 'boundary', required: false },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

export const addressesResource: ConfigResource = {
  table: 'addresses',
  singular: 'address',
  singularTitle: 'Address',
  pluralTitle: 'Addresses',
  description: 'Saved customer addresses and their map locations.',
  permission: 'manage_geography',
  group: 'Geography',
  hardDelete: true,
  writeRpc: GEOGRAPHY_WRITE_RPC,
  referenceCountsRpc: GEOGRAPHY_REFERENCES_RPC,
  selectSpec:
    'id, country_id, city_id, neighborhood_id, line_1, line_2, landmark, metadata, countries(name), cities(name), neighborhoods(name)',
  columns: [
    { key: 'line_1', label: 'Address', sortable: true },
    { key: 'city_name', label: 'City' },
    { key: 'neighborhood_name', label: 'Neighbourhood' },
    { key: 'landmark', label: 'Landmark' },
  ],
  searchColumns: ['line_1', 'landmark'],
  augment: (rows, ctx) => withGeometry(rows, ctx, 'addresses'),
  augmentRecord: (row, ctx) => withGeometry([row], ctx, 'addresses'),
  fields: [
    { name: 'country_id', label: 'Country', type: 'select', required: true, optionsKey: 'countries' },
    { name: 'city_id', label: 'City', type: 'select', required: true, optionsKey: 'cities' },
    {
      name: 'neighborhood_id',
      label: 'Neighbourhood',
      type: 'select',
      optionsKey: 'neighborhoods',
    },
    { name: 'line_1', label: 'Address line 1', type: 'text', required: true },
    { name: 'line_2', label: 'Address line 2', type: 'text' },
    { name: 'landmark', label: 'Landmark', type: 'text' },
    { ...wktField('Location (WKT)', ['POINT']), name: 'location' },
    { name: 'metadata', label: 'Metadata', type: 'json', defaultValue: {} },
  ],
  defaultSort: { column: 'line_1', ascending: true },
};
