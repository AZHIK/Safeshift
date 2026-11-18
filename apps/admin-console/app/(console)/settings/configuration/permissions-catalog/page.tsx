import { PermissionCatalogClient } from '@/components/configuration/permission-catalog-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { ADMIN_ROLE_NAMES, permissionsCatalog } from '@/lib/configuration/resources';
import { createClient } from '@/lib/supabase/server';

import {
  createPermission,
  getPermissionGrantAuditHistory,
  grantPermission,
  listPermissionGrants,
  revokePermission,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function PermissionsCatalogPage() {
  const { caller } = await requireConfigurationPermission('manage_admins');

  const supabase = await createClient();
  const filters = { page: 1, pageSize: 25 };
  const [options, initial, grantResult] = await Promise.all([
    loadOptionsFor(supabase, permissionsCatalog),
    listPermissionGrants(filters),
    supabase.from('admin_role_permissions').select('role_name, permission_key'),
  ]);

  const rolePermissions: Record<string, string[]> = {};
  for (const grant of (grantResult.data ?? []) as unknown as {
    role_name: string;
    permission_key: string;
  }[]) {
    (rolePermissions[grant.role_name] ??= []).push(grant.permission_key);
  }

  return (
    <>
      <PageHeader
        title="Permissions Catalog"
        description="Which permissions each admin role grants. A change here takes effect for every holder of that role the moment it is saved."
      />
      <PermissionCatalogClient
        actions={{
          list: listPermissionGrants,
          grant: grantPermission,
          revoke: revokePermission,
          createPermission,
          audit: getPermissionGrantAuditHistory,
        }}
        callerPermissions={[...caller.permissions]}
        isSuperAdmin={caller.isSuperAdmin}
        page={initial.page}
        pageSize={25}
        permissions={options.permissions ?? []}
        rolePermissions={rolePermissions}
        roles={ADMIN_ROLE_NAMES}
        rows={initial.rows ?? []}
        total={initial.total ?? 0}
      />
    </>
  );
}
