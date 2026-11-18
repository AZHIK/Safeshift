/**
 * Group 7 — Administration.
 *
 * admin_roles and admin_role_permissions. These two are the root of the RBAC
 * graph, so they are guarded by 'manage_admins' rather than the
 * 'manage_configuration' umbrella, and their writes go through dedicated
 * database functions (see migration 0132).
 */

import type { ConfigResource } from '../types';

export const ADMIN_ROLE_NAMES = [
  { value: 'super_admin', label: 'Super admin' },
  { value: 'operations_admin', label: 'Operations admin' },
  { value: 'verification_admin', label: 'Verification admin' },
  { value: 'support_agent', label: 'Support agent' },
  { value: 'finance_admin', label: 'Finance admin' },
  { value: 'analyst', label: 'Analyst' },
  { value: 'fleet_owner', label: 'Fleet owner' },
];

export const adminRolesResource: ConfigResource = {
  table: 'admin_roles',
  singular: 'admin role',
  singularTitle: 'Admin Role',
  pluralTitle: 'Admin Roles',
  description:
    'Who holds which admin role, and in which country or city. A grant with no country applies everywhere; a grant with no city applies to every city in that country.',
  permission: 'manage_admins',
  group: 'Administration',
  countryScoped: true,
  softDelete: true,
  selectSpec:
    'id, profile_id, role_name, country_id, city_id, is_active, granted_by, granted_at, expires_at, revoked_at, revoked_reason, created_at, updated_at, profiles(id, full_name, display_name, email), countries(name, iso_code), cities(name)',
  augment: async (rows) => {
    for (const row of rows) {
      const country = row.countries as { name?: string } | null;
      const city = row.cities as { name?: string } | null;
      if (city?.name) row.scope = `${city.name}, ${country?.name ?? 'all countries'}`;
      else if (country?.name) row.scope = country.name;
      else row.scope = 'All countries';
    }
  },
  columns: [
    { key: 'profile_name', label: 'Profile', sortable: true },
    { key: 'role_name', label: 'Role' },
    { key: 'scope', label: 'Scope' },
    { key: 'granted_at', label: 'Granted', kind: 'date' },
    { key: 'expires_at', label: 'Expires', kind: 'date' },
    { key: 'is_active', label: 'Status', kind: 'boolean', sortable: true },
  ],
  searchColumns: ['role_name'],
  fields: [
    {
      name: 'profile_id',
      label: 'Profile',
      type: 'profile',
      required: true,
      help: 'Search by name, phone or email. The person who will hold the role.',
    },
    {
      name: 'role_name',
      label: 'Role',
      type: 'select',
      required: true,
      options: ADMIN_ROLE_NAMES,
    },
    {
      name: 'country_id',
      label: 'Country scope',
      type: 'select',
      optionsKey: 'countries',
      help: 'Leave empty to grant the role in every country.',
    },
    {
      name: 'city_id',
      label: 'City scope',
      type: 'select',
      optionsKey: 'cities',
      dependsOn: { field: 'country_id', notEquals: '' },
      help: 'Leave empty to grant the role in every city of the country.',
    },
    {
      name: 'expires_at',
      label: 'Expires',
      type: 'date',
      help: 'Optional. The grant stops applying at this moment.',
    },
    {
      name: 'notes',
      label: 'Notes',
      type: 'textarea',
      formOnly: true,
      help: 'Recorded in the audit trail, not on the role row itself.',
    },
  ],
  defaultSort: { column: 'granted_at', ascending: false },
};

export const permissionsCatalogResource: ConfigResource = {
  table: 'admin_role_permissions',
  singular: 'role permission',
  singularTitle: 'Role Permission',
  pluralTitle: 'Permissions Catalog',
  description:
    'Which permissions each admin role grants. A change here takes effect for every holder of that role the moment it is saved.',
  permission: 'manage_admins',
  group: 'Administration',
  // admin_role_permissions has no is_active column and nothing points at it,
  // so removing a grant is a hard delete.
  hardDelete: true,
  selectSpec: 'id, role_name, permission_key, created_at',
  uniqueColumns: [{ columns: ['role_name', 'permission_key'], label: 'grant' }],
  augment: async (rows, ctx) => {
    if (rows.length === 0) return;
    const { data } = await ctx.client
      .from('admin_permissions_catalog')
      .select('permission_key, description, category');
    const catalog = new Map<string, { description: string; category: string }>();
    for (const row of (data ?? []) as {
      permission_key: string;
      description: string;
      category: string | null;
    }[]) {
      catalog.set(row.permission_key, {
        description: row.description,
        category: row.category ?? '—',
      });
    }
    for (const row of rows) {
      const entry = catalog.get(String(row.permission_key));
      row.description = entry?.description ?? '—';
      row.category = entry?.category ?? '—';
    }
  },
  columns: [
    { key: 'role_name', label: 'Role', sortable: true },
    { key: 'permission_key', label: 'Permission', kind: 'code', sortable: true },
    { key: 'description', label: 'Description' },
    { key: 'category', label: 'Category' },
  ],
  searchColumns: ['role_name', 'permission_key', 'description'],
  fields: [
    {
      name: 'role_name',
      label: 'Role',
      type: 'select',
      required: true,
      options: ADMIN_ROLE_NAMES,
    },
    {
      name: 'permission_key',
      label: 'Permission',
      type: 'select',
      required: true,
      optionsKey: 'permissions',
    },
  ],
  defaultSort: { column: 'role_name', ascending: true },
};
