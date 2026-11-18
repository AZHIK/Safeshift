/**
 * Group 4 — Support and safety.
 *
 * prohibited_items and support_categories.
 */

import type { ConfigResource } from '../types';

export const prohibitedItemsResource: ConfigResource = {
  table: 'prohibited_items',
  singular: 'prohibited item',
  singularTitle: 'Prohibited Item',
  pluralTitle: 'Prohibited Items',
  description:
    'The jurisdiction-specific list of things SafeShift will not carry, will only carry with a licence, or will only carry on a restricted route.',
  permission: 'manage_prohibited_items',
  group: 'Support & Safety',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, category, name, description, legal_reference, severity, is_active, created_at, updated_at, countries(name, iso_code)',
  columns: [
    { key: 'name', label: 'Name', sortable: true },
    { key: 'category', label: 'Category' },
    { key: 'country_name', label: 'Country' },
    { key: 'severity', label: 'Severity' },
    { key: 'legal_reference', label: 'Legal reference' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['name', 'description', 'legal_reference'],
  fields: [
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      required: true,
      optionsKey: 'countries',
      help: 'Prohibited items are jurisdiction specific, so a country is required.',
    },
    {
      name: 'category',
      label: 'Category',
      type: 'select',
      required: true,
      options: [
        { value: 'weapons', label: 'Weapons' },
        { value: 'drugs', label: 'Drugs' },
        { value: 'hazardous_materials', label: 'Hazardous materials' },
        { value: 'live_animals', label: 'Live animals' },
        { value: 'cash', label: 'Cash' },
        { value: 'illegal_goods', label: 'Illegal goods' },
        { value: 'other', label: 'Other' },
      ],
    },
    { name: 'name', label: 'Name', type: 'text', required: true },
    { name: 'description', label: 'Description', type: 'textarea' },
    {
      name: 'legal_reference',
      label: 'Legal reference',
      type: 'text',
      help: 'The statute or gazette notice this entry comes from.',
    },
    {
      name: 'severity',
      label: 'Severity',
      type: 'select',
      required: true,
      options: [
        { value: 'prohibited', label: 'Prohibited outright' },
        { value: 'requires_licence', label: 'Requires a licence' },
        { value: 'restricted_route', label: 'Restricted route' },
      ],
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  defaultSort: { column: 'name', ascending: true },
};

export const supportCategoriesResource: ConfigResource = {
  table: 'support_categories',
  singular: 'support category',
  singularTitle: 'Support Category',
  pluralTitle: 'Support Categories',
  description:
    'The list a customer picks from when they open a support ticket. A category with no country applies to every market.',
  permission: 'manage_support',
  group: 'Support & Safety',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, code, name, description, display_order, is_active, created_at, updated_at, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'code'], label: 'code in this country' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'display_order', label: 'Order', kind: 'number' },
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
    { name: 'display_order', label: 'Display order', type: 'number', defaultValue: 0, min: 0 },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  references: [{ key: 'support_tickets', label: 'open support tickets', blocking: true }],
  defaultSort: { column: 'display_order', ascending: true },
};
