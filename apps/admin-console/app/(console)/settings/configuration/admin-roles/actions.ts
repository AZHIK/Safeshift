'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

import type { AuditQuery } from '@/components/configuration/audit-history-button';
import {
  configurationAuditHistory,
  configurationReferences,
  createConfigurationRecord,
  listConfigurationRecords,
  updateConfigurationRecord,
} from '@/lib/configuration/action-helpers';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { adminRoles } from '@/lib/configuration/resources';
import {
  deactivateRecord,
  getRecord,
  logAdminAction,
  withAdminPermission,
} from '@/lib/configuration/server';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';
import type { SupabaseClient } from '@supabase/supabase-js';

type GrantResult = {
  success: boolean;
  error?: string;
  data?: { id: string };
};

/** Lists the admin role grants. */
export async function listAdminRoles(filters: ListFilters) {
  return listConfigurationRecords(adminRoles, filters);
}

/**
 * Creates one admin role grant.
 *
 * Only a super_admin may hand out the super_admin role: without that check
 * an administrator with manage_admins could escalate themselves.
 */
export async function createAdminRole(values: ConfigFieldValues) {
  const caller = await getCallerPermissions();
  if (values.role_name === 'super_admin' && !caller.isSuperAdmin) {
    return {
      success: false,
      error: 'Only a super admin may grant the super admin role.',
    };
  }

  return createConfigurationRecord(adminRoles, values);
}

/** Updates one admin role grant. */
export async function updateAdminRole(id: string, values: ConfigFieldValues) {
  const caller = await getCallerPermissions();
  if (values.role_name === 'super_admin' && !caller.isSuperAdmin) {
    return {
      success: false,
      error: 'Only a super admin may change a grant to the super admin role.',
    };
  }

  return updateConfigurationRecord(adminRoles, id, values);
}

/** Counts the live super admin grants, ignoring the expired ones. */
async function countLiveSuperAdmins(client: SupabaseClient): Promise<number> {
  const { data } = await client
    .from('admin_roles')
    .select('id, expires_at')
    .eq('role_name', 'super_admin')
    .eq('is_active', true)
    .is('revoked_at', null);

  const live = ((data ?? []) as { id: string; expires_at?: string | null }[]).filter(
    (entry) => !entry.expires_at || new Date(entry.expires_at) > new Date(),
  );
  return live.length;
}

/**
 * Revokes one admin role grant.
 *
 * The grant is deactivated and stamped as revoked rather than deleted: the
 * row records who held the role, who granted it and when, and deleting it
 * would erase that history. The check below refuses to revoke the last
 * active super admin, because nobody would be left able to undo it.
 */
export async function deactivateAdminRole(id: string, reason: string): Promise<GrantResult> {
  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const row = await getRecord(adminRoles, id, client);
    if (!row) {
      return { success: false, error: 'That grant no longer exists.' };
    }

    if (row.role_name === 'super_admin') {
      const live = await countLiveSuperAdmins(client);
      if (live <= 1) {
        return {
          success: false,
          error:
            'This is the last active super admin. Grant the role to somebody else before revoking it.',
        };
      }
    }

    const deactivated = await deactivateRecord(adminRoles, id, reason, client);
    if (!deactivated.success) {
      return { success: false, error: deactivated.error };
    }

    await logAdminAction(
      client,
      'admin_roles.revoked',
      'admin_roles',
      id,
      { revoked_at: null, is_active: true },
      { revoked_at: new Date().toISOString(), reason: reason || null },
      'manage_admins',
    );

    return { success: true, data: deactivated.data };
  });

  if (!result.ok) return { success: false, error: result.error };
  if (!result.value.success) {
    return { success: false, error: result.value.error ?? 'The grant could not be revoked.' };
  }

  revalidatePath('/settings/configuration/admin-roles');
  return { success: true, data: result.value.data };
}

/**
 * Removes one admin role grant outright.
 *
 * This is a hard delete and it is the only way to remove the record of a
 * grant; the last active super admin cannot be removed this way.
 */
export async function deleteAdminRole(id: string): Promise<GrantResult> {
  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const row = await getRecord(adminRoles, id, client);
    if (!row) {
      return { success: false, error: 'That grant no longer exists.' };
    }

    if (row.role_name === 'super_admin') {
      const live = await countLiveSuperAdmins(client);
      if (live <= 1) {
        return {
          success: false,
          error: 'The last active super admin cannot be removed.',
        };
      }
    }

    const { error } = await client.from('admin_roles').delete().eq('id', id);
    if (error) return { success: false, error: error.message };

    await logAdminAction(
      client,
      'admin_roles.deleted',
      'admin_roles',
      id,
      row,
      null,
      'manage_admins',
    );

    return { success: true, data: { id } };
  });

  if (!result.ok) return { success: false, error: result.error };
  if (!result.value.success) {
    return { success: false, error: result.value.error ?? 'The grant could not be removed.' };
  }

  revalidatePath('/settings/configuration/admin-roles');
  return { success: true, data: result.value.data };
}

/** Reads the audit trail of one admin role grant. */
export async function getAdminRoleAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(adminRoles, id, query);
}

/** Counts what still references one admin role grant. */
export async function getAdminRoleReferences(id: string) {
  return configurationReferences(adminRoles, id);
}

/**
 * Searches the profiles an administrator may be granted a role.
 *
 * The search runs through the database helper that records the PII access,
 * so the console never reads the profiles table directly.
 */
export async function searchAdminProfiles(query: string) {
  const result = await withAdminPermission('manage_admins', async ({ client }) => {
    const { data, error } = await client.rpc('admin_search_profiles', {
      p_query: query,
      p_limit: 20,
    });
    if (error) return [] as { id: string; name: string; email: string }[];

    return (
      (data ?? []) as {
        profile_id: string;
        full_name: string | null;
        display_name: string | null;
        email: string | null;
      }[]
    ).map((row) => ({
      id: row.profile_id,
      name: row.full_name ?? row.display_name ?? row.email ?? 'Unknown',
      email: row.email ?? '',
    }));
  });

  if (!result.ok) return [];
  return result.value;
}

export async function createRoleDefinition(form: FormData) {
  const client = await createClient();
  const path = '/settings/configuration/admin-roles';
  const {error} = await client.rpc('admin_create_role_definition', {
    p_name: String(form.get('name') ?? '').trim(), p_label: String(form.get('label') ?? '').trim(),
  });
  if (error) redirect(path + '?error=' + encodeURIComponent(error.code === '23505' ? 'This role name already exists.' : 'Could not create this role.'));
  revalidatePath(path);
  revalidatePath('/settings/configuration/permissions-catalog');
  redirect(path + '?ok=Role created. Assign its permissions in the permissions catalog.');
}
