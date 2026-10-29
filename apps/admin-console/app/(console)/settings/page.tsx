import Link from 'next/link';

import { toggleFeatureFlagAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { createClient } from '@/lib/supabase/server';

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
        <PageHeader title="Settings" description="Fleet-owner access is limited to your own fleet. Contact SafeShift operations for changes to your account." />
        <Notice searchParams={params} />
        <div className="card card-pad">
          <h2 className="card-title">Your access</h2>
          <p className="card-sub">Signed in as {session.email ?? session.name}.</p>
          <div style={{ marginTop: 12 }}><StatusBadge value="fleet_owner" /></div>
          <p className="small muted" style={{ marginTop: 14 }}>Role changes, billing configuration, and fleet ownership transfers are performed by SafeShift staff and recorded in the audit log.</p>
          <Link className="btn" href="/fleets">Open my fleet</Link>
        </div>
      </>
    );
  }

  const [{ data: flags, error: flagError }, { data: roles, error: roleError }, { data: categories }] = await Promise.all([
    supabase.from('feature_flags').select('id, flag_key, is_enabled, rollout_percentage, description, country_id, city_id, profile_id, updated_at').order('flag_key').limit(100),
    supabase.from('admin_roles').select('id, profile_id, role_name, country_id, city_id, is_active, granted_at, expires_at').eq('is_active', true).order('granted_at', { ascending: false }).limit(100),
    supabase.from('support_categories').select('id, name, code, is_active, display_order').order('display_order').limit(100),
  ]);
  const roleProfiles = await loadProfileSummaries(supabase, (roles ?? []).map((role) => role.profile_id));

  return (
    <>
      <PageHeader title="Settings" description="Feature rollouts, staff roles, and support taxonomy. Admin accounts are provisioned in Supabase; there is no self-registration." />
      <Notice searchParams={params} />
      {flagError ? <div className="notice notice-error">{flagError.message}</div> : null}
      {roleError ? <div className="notice notice-error">{roleError.message}</div> : null}
      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Feature flags</h2>
            <p className="card-sub">Global and scoped rollouts. Toggles are audited through RLS-protected admin permissions.</p>
          </div>
          <DataTable
            columns={['Flag', 'Scope', 'Rollout', 'Status', 'Updated', 'Action']}
            rows={(flags ?? []).map((flag) => [
              <div key="f"><strong className="mono">{flag.flag_key}</strong><div className="small muted">{flag.description ?? ''}</div></div>,
              <span className="small" key="s">{flag.profile_id ? `Profile ${shortId(flag.profile_id)}` : flag.city_id ? `City ${shortId(flag.city_id)}` : flag.country_id ? `Country ${shortId(flag.country_id)}` : 'Global'}</span>,
              `${flag.rollout_percentage ?? 0}%`,
              <StatusBadge key="b" value={flag.is_enabled ? 'enabled' : 'disabled'} />,
              <span className="small muted" key="u">{formatDate(flag.updated_at)}</span>,
              <form action={toggleFeatureFlagAction} key="a">
                <input type="hidden" name="flag_id" value={flag.id} />
                <input type="hidden" name="enabled" value={flag.is_enabled ? 'false' : 'true'} />
                <button className="btn btn-sm" type="submit">{flag.is_enabled ? 'Disable' : 'Enable'}</button>
              </form>,
            ])}
            empty="No feature flags configured."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Staff & fleet-owner roles</h2>
            <p className="card-sub">Active grants in public.admin_roles. Provision users in Supabase Studio or CLI.</p>
          </div>
          <DataTable
            columns={['Person', 'Role', 'Scope', 'Granted', 'Expires', 'Status']}
            rows={(roles ?? []).map((role) => {
              const profile = roleProfiles.get(role.profile_id);
              return [
                <div key="p" className="small">{profile?.full_name ?? shortId(role.profile_id)}<div className="muted">{profile?.email ?? ''}</div></div>,
                titleize(role.role_name),
                <span className="small" key="s">{role.city_id ? `City ${shortId(role.city_id)}` : role.country_id ? `Country ${shortId(role.country_id)}` : 'Global'}</span>,
                <span className="small muted" key="g">{formatDate(role.granted_at)}</span>,
                <span className="small muted" key="e">{role.expires_at ? formatDate(role.expires_at) : 'No expiry'}</span>,
                <StatusBadge key="b" value={role.is_active ? 'active' : 'disabled'} />,
              ];
            })}
            empty="No active role grants."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Support categories</h2>
            <p className="card-sub">Shared taxonomy used by customer and driver apps.</p>
          </div>
          <DataTable
            columns={['Name', 'Code', 'Order', 'Status']}
            rows={(categories ?? []).map((category) => [category.name, <span className="mono small" key="s">{category.code}</span>, category.display_order, <StatusBadge key="b" value={category.is_active ? 'active' : 'disabled'} />])}
            empty="No support categories."
          />
        </div>
      </div>
    </>
  );
}
