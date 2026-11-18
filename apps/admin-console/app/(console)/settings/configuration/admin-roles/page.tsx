import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { adminRoles } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createAdminRole,
  deactivateAdminRole,
  deleteAdminRole,
  getAdminRoleAuditHistory,
  getAdminRoleReferences,
  listAdminRoles,
  searchAdminProfiles,
  updateAdminRole,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function AdminRolesPage() {
  await requireConfigurationPermission('manage_admins');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, adminRoles),
    listAdminRoles(filters),
  ]);

  return (
    <>
      <PageHeader title={adminRoles.pluralTitle} description={adminRoles.description} />
      <ConfigurationClient
        actions={{
          list: listAdminRoles,
          create: createAdminRole,
          update: updateAdminRole,
          deactivate: deactivateAdminRole,
          remove: deleteAdminRole,
          audit: getAdminRoleAuditHistory,
          references: getAdminRoleReferences,
          searchProfiles: searchAdminProfiles,
        }}
        countries={options.countries ?? []}
        createLabel="Grant a role"
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(adminRoles)}
      />
    </>
  );
}
