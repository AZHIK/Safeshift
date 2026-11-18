/**
 * Permission helpers for the configuration console.
 *
 * The console decides what an administrator may see from the permissions the
 * database holds for them, not from a hard-coded role list: the role
 * permissions table is the single source of truth for the whole platform.
 */

import { cache } from 'react';
import { redirect } from 'next/navigation';

import { getAdminSession, type AdminSession } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';

import { CONFIGURATION_PERMISSIONS, CONFIGURATION_UMBRELLA_PERMISSIONS } from './resources';

export type CallerPermissions = {
  /** Every permission the caller holds, umbrella expanded. */
  permissions: Set<string>;
  /** The admin roles the caller holds. */
  roles: string[];
  /** True when the caller holds the super_admin role. */
  isSuperAdmin: boolean;
};

/**
 * The permissions of the signed-in administrator.
 *
 * Memoised for the lifetime of the request, so the shell, the layout and the
 * page guard all read the same set.
 */
export const getCallerPermissions = cache(async (): Promise<CallerPermissions> => {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_my_permissions');

  const permissions = new Set<string>();
  const roles = new Set<string>();

  if (!error && Array.isArray(data)) {
    for (const row of data as { permission_key: string; role_name: string }[]) {
      permissions.add(row.permission_key);
      roles.add(row.role_name);
    }
  }

  // Mirror the database umbrella so the console and the database agree on
  // who may open which page.
  if (permissions.has('manage_configuration')) {
    for (const key of CONFIGURATION_UMBRELLA_PERMISSIONS) {
      permissions.add(key);
    }
  }

  return {
    permissions,
    roles: [...roles],
    isSuperAdmin: roles.has('super_admin'),
  };
});

/** True when the signed-in administrator holds a permission. */
export async function hasPermission(permission: string): Promise<boolean> {
  const caller = await getCallerPermissions();
  return caller.permissions.has(permission);
}

/** True when the administrator may open at least one configuration page. */
export async function canManageConfiguration(): Promise<boolean> {
  const caller = await getCallerPermissions();
  return CONFIGURATION_PERMISSIONS.some((key) => caller.permissions.has(key));
}
/**
 * Guards a configuration page.
 *
 * Redirects to the login page when there is no session at all and to the
 * dashboard when the administrator holds the wrong permissions.
 */
export async function requireConfigurationPermission(
  permission: string,
): Promise<{ session: AdminSession; caller: CallerPermissions }> {
  const session = await getAdminSession();
  if (!session) {
    redirect('/login?error=Sign in with an admin account.');
  }

  const caller = await getCallerPermissions();
  if (!caller.permissions.has(permission)) {
    redirect(
      `/dashboard?error=${encodeURIComponent(
        'You do not have permission to manage this configuration.',
      )}`,
    );
  }

  return { session, caller };
}
