import { Notice } from '@/components/notice';
import Link from 'next/link';
import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { adminRoles } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createRoleDefinition,
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

export default async function AdminRolesPage({ searchParams }: { searchParams: Promise<Record<string,string | undefined>> }) {
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
      <Notice searchParams={await searchParams} />
      <details className="card card-pad"><summary>Create a custom role</summary>
        <form className="form" action={createRoleDefinition}>
          <label className="field">Role key<input className="input" name="name" required pattern="[a-z][a-z0-9_]{1,63}" placeholder="city_support_lead" /></label>
          <label className="field">Display name<input className="input" name="label" maxLength={100} required /></label>
          <button className="btn btn-primary">Create role</button>
        </form>
        <Link href="/settings/configuration/permissions-catalog">Manage role permissions</Link>
      </details>
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
