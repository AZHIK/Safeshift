/**
 * Group 1 — Vehicles.
 *
 * vehicle_types, vehicle_makes, vehicle_models and vehicle_equipment_catalog.
 */

import type { ConfigResource } from '../types';
import { CATALOG_ICON_BUCKET, ICON_ACCEPT_ATTRIBUTE, ICON_FOLDERS } from '../icons';

export const vehicleTypesResource: ConfigResource = {
  table: 'vehicle_types',
  singular: 'vehicle type',
  singularTitle: 'Vehicle Type',
  pluralTitle: 'Vehicle Types',
  description:
    'The sizes a customer can book and a driver can register against. The code is the durable key pricing rules point at, so changing it re-prices nothing on its own but does rename the row everywhere.',
  permission: 'manage_vehicle_catalog',
  group: 'Vehicles',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, code, name, description, icon_url, country_id, capacity_kg_min, capacity_kg_max, capacity_m3_min, capacity_m3_max, max_dimensions_cm, number_of_wheels, requires_special_licence, requires_equipment, display_order, is_active, created_at, updated_at, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'code'], label: 'code in this country' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'capacity_kg_min', label: 'Min kg', kind: 'number', sortable: true },
    { key: 'capacity_kg_max', label: 'Max kg', kind: 'number', sortable: true },
    { key: 'capacity_m3_min', label: 'Min m³', kind: 'number' },
    { key: 'capacity_m3_max', label: 'Max m³', kind: 'number' },
    { key: 'requires_special_licence', label: 'Special licence', kind: 'boolean' },
    { key: 'pricing_plan_count', label: 'Pricing' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['code', 'name', 'description'],
  augment: async (rows, ctx) => {
    const { data, error } = await ctx.client.rpc('admin_pricing_coverage');
    if (error || !data) return;
    const counts = new Map<string, number>();
    for (const entry of data as { vehicle_type_id: string; pricing_plan_count: number }[]) {
      counts.set(entry.vehicle_type_id, Number(entry.pricing_plan_count ?? 0));
    }
    for (const row of rows) {
      row.pricing_plan_count = counts.get(String(row.id)) ?? 0;
    }
  },
  fields: [
    {
      name: 'country_id',
      label: 'Applies to',
      type: 'select',
      optionsKey: 'countries',
      help: 'Leave empty to apply to every country.',
    },
    {
      name: 'code',
      label: 'Code',
      type: 'text',
      required: true,
      placeholder: 'pickup-van',
      help: 'Unique within the selected scope. Lower case, underscores only.',
      validate: (value) =>
        /^[a-z0-9_]+$/.test(String(value ?? ''))
          ? null
          : 'Use lower case letters, digits and underscores only.',
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'icon_url',
      label: 'Icon',
      type: 'file',
      upload: {
        bucket: CATALOG_ICON_BUCKET,
        folder: ICON_FOLDERS.vehicle,
        accept: ICON_ACCEPT_ATTRIBUTE,
        nameFrom: 'code',
      },
      help: 'Choose an SVG, PNG, JPEG or WebP file from your computer, up to 512 KB. It is uploaded to the public catalogue bucket and named after the code.',
    },
    {
      name: 'capacity_kg_min',
      label: 'Minimum capacity (kg)',
      type: 'number',
      required: true,
      min: 1,
      step: 1,
    },
    {
      name: 'capacity_kg_max',
      label: 'Maximum capacity (kg)',
      type: 'number',
      required: true,
      min: 1,
      step: 1,
    },
    { name: 'capacity_m3_min', label: 'Minimum capacity (m³)', type: 'number', min: 0, step: 0.1 },
    { name: 'capacity_m3_max', label: 'Maximum capacity (m³)', type: 'number', min: 0, step: 0.1 },
    {
      name: 'max_dimensions_cm',
      label: 'Maximum dimensions (cm)',
      type: 'json',
      placeholder: '{ "length": 400, "width": 200, "height": 220 }',
      help: 'A JSON object with length, width and height.',
    },
    { name: 'number_of_wheels', label: 'Number of wheels', type: 'number', min: 1 },
    {
      name: 'requires_special_licence',
      label: 'Requires a special licence',
      type: 'checkbox',
    },
    {
      name: 'requires_equipment',
      label: 'Required equipment',
      type: 'multi-select',
      optionsKey: 'vehicle_equipment',
      help: 'Equipment a driver must have on board to take this vehicle type.',
    },
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  crossRules: [
    {
      field: 'capacity_kg_max',
      type: 'gte',
      against: 'capacity_kg_min',
      message: 'Maximum capacity must not be smaller than the minimum.',
    },
    {
      field: 'capacity_m3_max',
      type: 'gte',
      against: 'capacity_m3_min',
      message: 'Maximum volume must not be smaller than the minimum.',
    },
  ],
  references: [
    { key: 'vehicles', label: 'active vehicles', blocking: true },
    { key: 'pricing_plans', label: 'pricing plans', blocking: true },
    { key: 'quote_requests', label: 'quote requests', blocking: true },
    { key: 'vehicle_models', label: 'vehicle models', blocking: false },
  ],
  defaultSort: { column: 'display_order', ascending: true },
  special: 'pricing-warning',
};

export const vehicleMakesResource: ConfigResource = {
  table: 'vehicle_makes',
  singular: 'vehicle make',
  singularTitle: 'Vehicle Make',
  pluralTitle: 'Vehicle Makes',
  description:
    'Manufacturers. Makes are global — they are not scoped to a country, because a manufacturer serves every market.',
  permission: 'manage_vehicle_catalog',
  group: 'Vehicles',
  softDelete: true,
  selectSpec: 'id, name, country_of_origin, is_active, created_at, updated_at',
  uniqueColumns: [{ columns: ['name'], label: 'name' }],
  columns: [
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_of_origin', label: 'Country of origin' },
    { key: 'model_count', label: 'Models', kind: 'number' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'country_of_origin'],
  fields: [
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'country_of_origin', label: 'Country of origin', type: 'text' },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  references: [
    { key: 'vehicle_models', label: 'vehicle models', blocking: true },
    { key: 'vehicles', label: 'vehicles', blocking: true },
  ],
  augment: async (rows, ctx) => {
    if (rows.length === 0) return;
    const { data } = await ctx.client.from('vehicle_models').select('make_id');
    const counts = new Map<string, number>();
    for (const model of (data ?? []) as { make_id: string }[]) {
      counts.set(model.make_id, (counts.get(model.make_id) ?? 0) + 1);
    }
    for (const row of rows) {
      row.model_count = counts.get(String(row.id)) ?? 0;
    }
  },
  defaultSort: { column: 'name', ascending: true },
};

export const vehicleModelsResource: ConfigResource = {
  table: 'vehicle_models',
  singular: 'vehicle model',
  singularTitle: 'Vehicle Model',
  pluralTitle: 'Vehicle Models',
  description:
    'A model of a make, optionally tied to the vehicle type it belongs to. The year range is a hint for operators, not a restriction.',
  permission: 'manage_vehicle_catalog',
  group: 'Vehicles',
  softDelete: true,
  selectSpec:
    'id, make_id, name, vehicle_type_id, year_start, year_end, is_active, created_at, updated_at, vehicle_makes(name), vehicle_types(name)',
  uniqueColumns: [{ columns: ['make_id', 'name'], label: 'model name for this make' }],
  columns: [
    { key: 'make_name', label: 'Make' },
    { key: 'name', label: 'Model', sortable: true },
    { key: 'vehicle_type_name', label: 'Vehicle type' },
    { key: 'year_start', label: 'From', kind: 'number' },
    { key: 'year_end', label: 'To', kind: 'number' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name'],
  fields: [
    {
      name: 'make_id',
      label: 'Make',
      type: 'select',
      required: true,
      optionsKey: 'vehicle_makes',
    },
    { name: 'name', label: 'Model name', type: 'text', required: true },
    {
      name: 'vehicle_type_id',
      label: 'Vehicle type',
      type: 'select',
      optionsKey: 'vehicle_types',
      help: 'Optional. Links the model to a bookable vehicle type.',
    },
    { name: 'year_start', label: 'First model year', type: 'number', min: 1900, max: 2200 },
    { name: 'year_end', label: 'Last model year', type: 'number', min: 1900, max: 2200 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  crossRules: [
    {
      field: 'year_end',
      type: 'gte',
      against: 'year_start',
      message: 'The last model year must not be earlier than the first.',
    },
  ],
  references: [{ key: 'vehicles', label: 'vehicles', blocking: true }],
  defaultSort: { column: 'name', ascending: true },
};

export const vehicleEquipmentResource: ConfigResource = {
  table: 'vehicle_equipment_catalog',
  singular: 'vehicle equipment',
  singularTitle: 'Vehicle Equipment',
  pluralTitle: 'Vehicle Equipment',
  description:
    'The catalogue of equipment a vehicle may be required to carry: tail lifts, refrigeration units, load straps and so on.',
  permission: 'manage_vehicle_catalog',
  group: 'Vehicles',
  softDelete: true,
  selectSpec: 'id, code, name, description, icon_url, category, is_active, created_at, updated_at',
  uniqueColumns: [{ columns: ['code'], label: 'code' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'category', label: 'Category' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['code', 'name', 'description'],
  fields: [
    {
      name: 'code',
      label: 'Code',
      type: 'text',
      required: true,
      placeholder: 'tail_lift',
      validate: (value) =>
        /^[a-z0-9_]+$/.test(String(value ?? ''))
          ? null
          : 'Use lower case letters, digits and underscores only.',
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'icon_url',
      label: 'Icon',
      type: 'file',
      upload: {
        bucket: CATALOG_ICON_BUCKET,
        folder: ICON_FOLDERS.vehicle,
        accept: ICON_ACCEPT_ATTRIBUTE,
        nameFrom: 'code',
      },
      help: 'Choose an SVG, PNG, JPEG or WebP file from your computer, up to 512 KB. It is uploaded to the public catalogue bucket and named after the code.',
    },
    {
      name: 'category',
      label: 'Category',
      type: 'select',
      options: [
        { value: 'safety', label: 'Safety' },
        { value: 'handling', label: 'Handling' },
        { value: 'protection', label: 'Protection' },
        { value: 'specialty', label: 'Specialty' },
      ],
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'code', ascending: true },
};
