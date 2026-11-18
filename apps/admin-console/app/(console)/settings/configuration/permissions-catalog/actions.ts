'use server';

import { revalidatePath } from 'next/cache';

import type { AuditQuery } from '@/components/configuration/audit-history-button';
import {
  configurationAuditHistory,
  configurationReferences,
  listConfigurationRecords,
} from '@/lib/configuration/action-helpers';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { permissionsCatalog } from '@/lib/configuration/resources';
import { getRecord, withAdminPermission } from '@/lib/configuration/server';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

type GrantResult = {
  success: boolean;
  error?: string;
  data?: { id: string };
};

/** Lists the permission grants, joined with the permission catalogue. */
export async function listPermissionGrants(filters: ListFilters) {
  return listConfigurationRecords(permissionsCatalog, filters);
}

/**
 * Grants one permission to one admin role.
 *
 * The write goes through the database function because
 * public.admin_role_permissions is deliberately read-only for the
 * authenticated role: it is the root of the RBAC graph.
 */
export async function grantPermission(values: ConfigFieldValues): Promise<GrantResult> {
  const roleName = String(values.role_name ?? '').trim();
  const permissionKey = String(values.permission_key ?? '').trim();

  if (!roleName || !permissionKey) {
    return { success: false, error: 'Choose a role and a permission.' };
  }

  const caller = await getCallerPermissions();
  if (roleName === 'super_admin' && !caller.isSuperAdmin) {
    return {
      success: false,
      error: 'Only a super admin may change the super admin role.',
    };
  }

  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const { error } = await client.rpc('admin_grant_permission', {
      p_role_name: roleName,
      p_permission_key: permissionKey,
    });
    if (error) return { success: false, error: error.message };

    return { success: true, data: { id: `${roleName}:${permissionKey}` } };
  });

  if (!result.ok) return { success: false, error: result.error };
  if (!result.value.success) {
    return { success: false, error: result.value.error ?? 'The permission could not be granted.' };
  }

  revalidatePath('/settings/configuration/permissions-catalog');
  return { success: true, data: result.value.data };
}

/** Removes one permission from one admin role. */
export async function revokePermission(
  roleName: string,
  permissionKey: string,
): Promise<GrantResult> {
  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const { error } = await client.rpc('admin_revoke_permission', {
      p_role_name: roleName,
      p_permission_key: permissionKey,
    });
    if (error) return { success: false, error: error.message };
    return { success: true, data: { id: `${roleName}:${permissionKey}` } };
  });

  if (!result.ok) return { success: false, error: result.error };
  if (!result.value.success) {
    return { success: false, error: result.value.error ?? 'The permission could not be revoked.' };
  }

  revalidatePath('/settings/configuration/permissions-catalog');
  return { success: true, data: result.value.data };
}

/**
 * Creates a new permission in the catalogue.
 *
 * The permission is available to the roles it is granted to straight away.
 */
export async function createPermission(values: ConfigFieldValues): Promise<GrantResult> {
  const permissionKey = String(values.permission_key ?? '').trim();
  const description = String(values.description ?? '').trim();
  const category = values.category ? String(values.category) : null;

  if (!permissionKey) return { success: false, error: 'A permission key is required.' };
  if (!description) return { success: false, error: 'A description is required.' };

  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const { error } = await client.rpc('admin_create_permission', {
      p_permission_key: permissionKey,
      p_description: description,
      p_category: category,
    });
    if (error) return { success: false, error: error.message };
    return { success: true, data: { id: permissionKey } };
  });

  if (!result.ok) return { success: false, error: result.error };
  if (!result.value.success) {
    return { success: false, error: result.value.error ?? 'The permission could not be created.' };
  }

  revalidatePath('/settings/configuration/permissions-catalog');
  return { success: true, data: result.value.data };
}

/** Reads the audit trail of one Permission. */
export async function getPermissionGrantAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(permissionsCatalog, id, query);
}

/** Counts what still references one Permission. */
export async function getPermissionGrantReferences(id: string) {
  return configurationReferences(permissionsCatalog, id);
}

/** Reads one grant, used by the audit drawer. */
export async function readPermissionGrant(id: string) {
  const result = await withAdminPermission('manage_admins', async ({ client }) =>
    getRecord(permissionsCatalog, id, client),
  );
  if (!result.ok) return null;
  return result.value;
}
