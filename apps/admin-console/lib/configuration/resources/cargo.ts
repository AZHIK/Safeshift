/**
 * Group 2 — Cargo.
 *
 * cargo_categories, cargo_types, cargo_restrictions and cargo_packaging_options.
 */

import type { ConfigResource } from '../types';
import { CATALOG_ICON_BUCKET, ICON_ACCEPT_ATTRIBUTE, ICON_FOLDERS } from '../icons';

export const cargoCategoriesResource: ConfigResource = {
  table: 'cargo_categories',
  singular: 'cargo category',
  singularTitle: 'Cargo Category',
  pluralTitle: 'Cargo Categories',
  description:
    'A hierarchy of cargo groupings. A category with no parent is a top-level group; the console only offers top-level groups as parents so the tree stays one level deep.',
  permission: 'manage_cargo_catalog',
  group: 'Cargo',
  softDelete: true,
  selectSpec:
    'id, code, name, description, icon_url, parent_category_id, display_order, is_active, created_at, updated_at',
  uniqueColumns: [{ columns: ['code'], label: 'code' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'parent_name', label: 'Parent category' },
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
        folder: ICON_FOLDERS.cargo,
        accept: ICON_ACCEPT_ATTRIBUTE,
        nameFrom: 'code',
      },
      help: 'Choose an SVG, PNG, JPEG or WebP file from your computer, up to 512 KB. It is uploaded to the public catalogue bucket and named after the code.',
    },
    {
      name: 'parent_category_id',
      label: 'Parent category',
      type: 'select',
      optionsKey: 'cargo_root_categories',
      help: 'Optional. Only top-level categories can be a parent.',
    },
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  references: [{ key: 'cargo_types', label: 'cargo types', blocking: true }],
  defaultSort: { column: 'display_order', ascending: true },
};

export const cargoTypesResource: ConfigResource = {
  table: 'cargo_types',
  singular: 'cargo type',
  singularTitle: 'Cargo Type',
  pluralTitle: 'Cargo Types',
  description:
    'What a customer says they are moving. An empty allow list means the cargo may travel in any vehicle type; prohibited codes are rejected by the capability check before a quote is produced.',
  permission: 'manage_cargo_catalog',
  group: 'Cargo',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, category_id, code, name, description, icon_url, requires_special_handling, requires_declared_value, requires_insurance, allowed_vehicle_type_codes, prohibited_vehicle_type_codes, max_value_tzs, display_order, is_active, created_at, updated_at, countries(name, iso_code), cargo_categories(name)',
  uniqueColumns: [{ columns: ['country_id', 'code'], label: 'code in this country' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'category_name', label: 'Category' },
    { key: 'requires_special_handling', label: 'Special handling', kind: 'boolean' },
    { key: 'requires_insurance', label: 'Insurance', kind: 'boolean' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['code', 'name', 'description'],
  fields: [
    {
      name: 'country_id',
      label: 'Applies to',
      type: 'select',
      optionsKey: 'countries',
      help: 'Leave empty to apply to every country.',
    },
    {
      name: 'category_id',
      label: 'Category',
      type: 'select',
      optionsKey: 'cargo_categories',
    },
    {
      name: 'code',
      label: 'Code',
      type: 'text',
      required: true,
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
        folder: ICON_FOLDERS.cargo,
        accept: ICON_ACCEPT_ATTRIBUTE,
        nameFrom: 'code',
      },
      help: 'Choose an SVG, PNG, JPEG or WebP file from your computer, up to 512 KB. It is uploaded to the public catalogue bucket and named after the code.',
    },
    { name: 'requires_special_handling', label: 'Requires special handling', type: 'checkbox' },
    { name: 'requires_declared_value', label: 'Requires a declared value', type: 'checkbox' },
    { name: 'requires_insurance', label: 'Requires insurance', type: 'checkbox' },
    {
      name: 'allowed_vehicle_type_codes',
      label: 'Allowed vehicle types',
      type: 'multi-select',
      optionsKey: 'vehicle_type_codes',
      help: 'Leave empty to allow every vehicle type.',
    },
    {
      name: 'prohibited_vehicle_type_codes',
      label: 'Prohibited vehicle types',
      type: 'multi-select',
      optionsKey: 'vehicle_type_codes',
    },
    { name: 'max_value_tzs', label: 'Maximum value (TZS)', type: 'number', min: 0 },
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  references: [
    { key: 'quote_requests', label: 'quote requests', blocking: true },
    { key: 'cargo_equipment_surcharges', label: 'pricing surcharges', blocking: true },
    { key: 'cargo_restrictions', label: 'cargo restrictions', blocking: false },
  ],
  defaultSort: { column: 'display_order', ascending: true },
};

export const cargoRestrictionsResource: ConfigResource = {
  table: 'cargo_restrictions',
  singular: 'cargo restriction',
  singularTitle: 'Cargo Restriction',
  pluralTitle: 'Cargo Restrictions',
  description:
    'Rules that stop two cargo types from travelling together, or that demand a certificate, a special vehicle or a restricted route.',
  permission: 'manage_cargo_catalog',
  group: 'Cargo',
  softDelete: true,
  selectSpec:
    'id, cargo_type_id, restriction_type, restricted_with_cargo_type_id, restriction_details, description, is_active, created_at, updated_at, cargo_types(id, code, name)',
  augment: async (rows, ctx) => {
    if (rows.length === 0) return;
    const { data } = await ctx.client.from('cargo_types').select('id, code, name');
    const names = new Map<string, string>();
    for (const type of (data ?? []) as { id: string; code: string; name: string }[]) {
      names.set(type.id, `${type.name} (${type.code})`);
    }
    for (const row of rows) {
      const cargo = row.cargo_types as { id?: string; code?: string; name?: string } | null;
      row.cargo_type_name = cargo ? (names.get(String(cargo.id)) ?? cargo.name) : null;
      row.restricted_with_name = row.restricted_with_cargo_type_id
        ? (names.get(String(row.restricted_with_cargo_type_id)) ?? null)
        : null;
    }
  },
  columns: [
    { key: 'cargo_type_name', label: 'Cargo type' },
    { key: 'restriction_type', label: 'Restriction' },
    { key: 'restricted_with_name', label: 'Restricted with' },
    { key: 'description', label: 'Description' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['description'],
  fields: [
    {
      name: 'cargo_type_id',
      label: 'Cargo type',
      type: 'select',
      required: true,
      optionsKey: 'cargo_types',
    },
    {
      name: 'restriction_type',
      label: 'Restriction type',
      type: 'select',
      required: true,
      options: [
        { value: 'cannot_combine', label: 'Cannot be combined with' },
        { value: 'requires_certificate', label: 'Requires a certificate' },
        { value: 'requires_special_vehicle', label: 'Requires a special vehicle' },
        { value: 'age_restricted', label: 'Age restricted' },
        { value: 'prohibited_route', label: 'Prohibited route' },
        { value: 'time_restricted', label: 'Time restricted' },
      ],
    },
    {
      name: 'restricted_with_cargo_type_id',
      label: 'Restricted with cargo type',
      type: 'select',
      optionsKey: 'cargo_types',
      dependsOn: { field: 'restriction_type', equals: 'cannot_combine' },
      help: 'Only used when the restriction type is "Cannot be combined with".',
    },
    {
      name: 'restriction_details',
      label: 'Restriction details',
      type: 'json',
      defaultValue: {},
      help: 'A JSON object. The structure depends on the restriction type.',
    },
    { name: 'description', label: 'Description', type: 'textarea', required: true },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'restriction_type', ascending: true },
};

export const cargoPackagingResource: ConfigResource = {
  table: 'cargo_packaging_options',
  singular: 'packaging option',
  singularTitle: 'Packaging Option',
  pluralTitle: 'Packaging Options',
  description:
    'Packaging a customer can add to a shipment, with the surcharge it carries. The fee is in Tanzanian shillings.',
  permission: 'manage_cargo_catalog',
  group: 'Cargo',
  softDelete: true,
  selectSpec:
    'id, code, name, description, additional_fee_tzs, display_order, is_active, created_at, updated_at',
  uniqueColumns: [{ columns: ['code'], label: 'code' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'additional_fee_tzs', label: 'Fee (TZS)', kind: 'number' },
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
        /^[a-z0-9_]+$/.test(String(value ?? ''))
          ? null
          : 'Use lower case letters, digits and underscores only.',
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'additional_fee_tzs',
      label: 'Additional fee (TZS)',
      type: 'number',
      defaultValue: 0,
      min: 0,
    },
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'display_order', ascending: true },
};
