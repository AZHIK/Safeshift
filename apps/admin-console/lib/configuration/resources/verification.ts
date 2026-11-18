/**
 * Group 3 — Verification and documents.
 *
 * document_types and verification_checklist_templates.
 */

import type { ConfigResource } from '../types';

export const documentTypesResource: ConfigResource = {
  table: 'document_types',
  singular: 'document type',
  singularTitle: 'Document Type',
  pluralTitle: 'Document Types',
  description:
    'The documents the platform asks for. A document type with no country applies everywhere; the code is the key the mobile apps request.',
  permission: 'manage_document_types',
  group: 'Verification',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, country_id, code, name, description, applies_to, is_required, has_expiry, validity_days, verification_sla_hours, is_active, created_at, updated_at, countries(name, iso_code)',
  uniqueColumns: [{ columns: ['country_id', 'code'], label: 'code in this country' }],
  columns: [
    { key: 'code', label: 'Code', kind: 'code', sortable: true },
    { key: 'name', label: 'Name', sortable: true },
    { key: 'country_name', label: 'Country' },
    { key: 'applies_to', label: 'Applies to' },
    { key: 'is_required', label: 'Required', kind: 'boolean' },
    { key: 'has_expiry', label: 'Expires', kind: 'boolean' },
    { key: 'verification_sla_hours', label: 'SLA (h)', kind: 'number' },
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
    {
      name: 'applies_to',
      label: 'Applies to',
      type: 'select',
      required: true,
      options: [
        { value: 'driver', label: 'Driver' },
        { value: 'vehicle', label: 'Vehicle' },
        { value: 'business', label: 'Business' },
        { value: 'both', label: 'Driver and vehicle' },
      ],
    },
    { name: 'is_required', label: 'Required', type: 'checkbox' },
    { name: 'has_expiry', label: 'The document expires', type: 'checkbox', defaultValue: true },
    {
      name: 'validity_days',
      label: 'Validity (days)',
      type: 'number',
      min: 1,
      help: 'Required when the document expires.',
    },
    {
      name: 'verification_sla_hours',
      label: 'Verification SLA (hours)',
      type: 'number',
      defaultValue: 24,
      min: 1,
    },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  crossRules: [
    {
      field: 'validity_days',
      type: 'required_when',
      against: 'has_expiry',
      equals: true,
      message: 'Validity in days is required when the document expires.',
    },
  ],
  references: [
    { key: 'driver_documents', label: 'driver documents', blocking: true },
    { key: 'vehicle_documents', label: 'vehicle documents', blocking: true },
  ],
  defaultSort: { column: 'code', ascending: true },
};

export const verificationChecklistsResource: ConfigResource = {
  table: 'verification_checklist_templates',
  singular: 'checklist template',
  singularTitle: 'Checklist Template',
  pluralTitle: 'Verification Checklists',
  description:
    'The document list a verification request is checked against, per country and per request type.',
  permission: 'manage_document_types',
  group: 'Verification',
  countryScoped: true,
  softDelete: true,
  referenceResource: 'verification_checklists',
  selectSpec:
    'id, country_id, request_type, required_document_codes, optional_document_codes, description, is_active, created_at, updated_at, countries(name, iso_code)',
  uniqueColumns: [
    {
      columns: ['country_id', 'request_type'],
      label: 'checklist for this country and request type',
    },
  ],
  augment: async (rows) => {
    for (const row of rows) {
      row.required_count = Array.isArray(row.required_document_codes)
        ? row.required_document_codes.length
        : 0;
      row.optional_count = Array.isArray(row.optional_document_codes)
        ? row.optional_document_codes.length
        : 0;
    }
  },
  columns: [
    { key: 'country_name', label: 'Country' },
    { key: 'request_type', label: 'Request type' },
    { key: 'required_count', label: 'Required', kind: 'number' },
    { key: 'optional_count', label: 'Optional', kind: 'number' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['description'],
  fields: [
    {
      name: 'country_id',
      label: 'Country',
      type: 'select',
      required: true,
      optionsKey: 'countries',
    },
    {
      name: 'request_type',
      label: 'Request type',
      type: 'select',
      required: true,
      options: [
        { value: 'driver_verification', label: 'Driver verification' },
        { value: 'vehicle_verification', label: 'Vehicle verification' },
        { value: 'business_verification', label: 'Business verification' },
      ],
    },
    {
      name: 'required_document_codes',
      label: 'Required documents',
      type: 'multi-select',
      optionsKey: 'document_codes',
    },
    {
      name: 'optional_document_codes',
      label: 'Optional documents',
      type: 'multi-select',
      optionsKey: 'document_codes',
    },
    { name: 'description', label: 'Description', type: 'textarea' },
    { name: 'is_active', label: 'Active', type: 'checkbox', defaultValue: true },
  ],
  references: [
    {
      key: 'verification_requests',
      label: 'verification requests in this country',
      blocking: true,
    },
  ],
  defaultSort: { column: 'request_type', ascending: true },
};
