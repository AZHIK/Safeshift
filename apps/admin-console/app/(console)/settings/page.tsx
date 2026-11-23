import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireArea('settings');
  const params = await searchParams;
  const supabase = await createClient();

  if (session.role === 'fleet_owner') {
    return (
      <>
        <PageHeader
          title="Settings"
          description="Fleet-owner access is limited to your own fleet. Contact SafeShift operations for changes to your account."
        />
        <Notice searchParams={params} />
        <div className="card card-pad">
          <h2 className="card-title">Your access</h2>
          <p className="card-sub">Signed in as {session.email ?? session.name}.</p>
          <div style={{ marginTop: 12 }}>
            <StatusBadge value="fleet_owner" />
          </div>
          <p className="small muted" style={{ marginTop: 14 }}>
            Role changes, billing configuration, and fleet ownership transfers are performed by
            SafeShift staff and recorded in the audit log.
          </p>
          <Link className="btn" href="/fleets">
            Open my fleet
          </Link>
        </div>
      </>
    );
  }

  const [
    { data: roles, error: roleError },
    { data: categories },
  ] = await Promise.all([
    supabase
      .from('admin_roles')
      .select('id, profile_id, role_name, country_id, city_id, is_active, granted_at, expires_at')
      .eq('is_active', true)
      .order('granted_at', { ascending: false })
      .limit(100),
    supabase
      .from('support_categories')
      .select('id, name, code, is_active, display_order')
      .order('display_order')
      .limit(100),
  ]);
  const roleProfiles = await loadProfileSummaries(
    supabase,
    (roles ?? []).map((role) => role.profile_id),
  );

  return (
    <>
      <PageHeader
        title="Settings"
        description="Staff roles and support categories. Admin accounts are provisioned in Supabase; there is no self-registration."
      />
      <Notice searchParams={params} />
      {roleError ? <div className="notice notice-error">{roleError.message}</div> : null}
      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Staff & fleet-owner roles</h2>
            <p className="card-sub">
              Active grants in public.admin_roles. Provision users in Supabase Studio or CLI.
            </p>
          </div>
          <DataTable
            columns={['Person', 'Role', 'Scope', 'Granted', 'Expires', 'Status']}
            rows={(roles ?? []).map((role) => {
              const profile = roleProfiles.get(role.profile_id);
              return [
                <div key="p" className="small">
                  {profile?.full_name ?? shortId(role.profile_id)}
                  <div className="muted">{profile?.email ?? ''}</div>
                </div>,
                titleize(role.role_name),
                <span className="small" key="s">
                  {role.city_id
                    ? `City ${shortId(role.city_id)}`
                    : role.country_id
                      ? `Country ${shortId(role.country_id)}`
                      : 'Global'}
                </span>,
                <span className="small muted" key="g">
                  {formatDate(role.granted_at)}
                </span>,
                <span className="small muted" key="e">
                  {role.expires_at ? formatDate(role.expires_at) : 'No expiry'}
                </span>,
                <StatusBadge key="b" value={role.is_active ? 'active' : 'disabled'} />,
              ];
            })}
            actions={(roles ?? []).map((role) => (
              <RecordActions
                key={role.id}
                table="admin_roles"
                id={role.id}
                viewHref={`/users/${role.profile_id}`}
                items={[{ kind: 'link', label: 'Manage roles and access', href: '/settings/configuration/admin-roles' }]}
              />
            ))}
            empty="No active role grants."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Support categories</h2>
            <p className="card-sub">Shared taxonomy used by customer and driver apps.</p>
            <Link className="btn btn-sm" href="/data/support_categories/new" style={{ marginTop: 8 }}>
              Add category
            </Link>
          </div>
          <DataTable
            columns={['Name', 'Code', 'Order', 'Status']}
            rows={(categories ?? []).map((category) => [
              category.name,
              <span className="mono small" key="s">
                {category.code}
              </span>,
              category.display_order,
              <StatusBadge key="b" value={category.is_active ? 'active' : 'disabled'} />,
            ])}
            actions={(categories ?? []).map((category) => (
              <RecordActions key={category.id} table="support_categories" id={category.id} label={`Actions for ${category.name}`} />
            ))}
            empty="No support categories."
          />
        </div>
      </div>
    </>
  );
}
