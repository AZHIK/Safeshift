import Link from 'next/link';
import { notFound } from 'next/navigation';

import { AccountStatusPanel, DriverStatusPanel, StatusHistory, type HistoryRow } from '@/components/account-controls';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { formatDate, shortId, titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type Profile = {
  id: string;
  full_name: string | null;
  display_name: string | null;
  phone: string | null;
  email: string | null;
  primary_role: string;
  is_active: boolean;
  deactivated_at: string | null;
  deactivation_reason: string | null;
  created_at: string;
};
type Driver = {
  id: string;
  verification_status: string;
  is_available: boolean;
  suspension_reason: string | null;
  suspended_at: string | null;
};

export default async function UserDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('users');
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const supabase = await createClient();

  const [{ data: profile, error }, { data: driver }, { data: history }, { data: roles }] = await Promise.all([
    supabase
      .from('profiles')
      .select('id, full_name, display_name, phone, email, primary_role, is_active, deactivated_at, deactivation_reason, created_at')
      .eq('id', id)
      .maybeSingle(),
    supabase
      .from('drivers')
      .select('id, verification_status, is_available, suspension_reason, suspended_at')
      .eq('id', id)
      .maybeSingle(),
    supabase.rpc('admin_account_history', { p_entity_id: id, p_limit: 50 }),
    supabase.from('admin_roles').select('role_name').eq('profile_id', id).eq('is_active', true).is('revoked_at', null),
  ]);
  if (error) {
    return (
      <>
        <PageHeader title="Account" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!profile) notFound();

  const p = profile as Profile;
  const d = driver as Driver | null;
  const name = p.full_name?.trim() || p.display_name || 'this user';
  const back = `/users/${p.id}`;
  const staffRoles = ((roles ?? []) as { role_name: string }[]).map((r) => titleize(r.role_name));

  return (
    <>
      <PageHeader
        title={p.full_name?.trim() || p.display_name || 'Unnamed account'}
        description={`${titleize(p.primary_role)}${staffRoles.length ? ` · Staff: ${staffRoles.join(', ')}` : ''} · joined ${formatDate(p.created_at)}`}
        actions={
          <>
            <Link className="btn" href="/users">
              All users
            </Link>
            {d ? (
              <Link className="btn" href={`/drivers/${p.id}`}>
                Driver profile
              </Link>
            ) : null}
          </>
        }
      />
      <Notice searchParams={query} />

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <div className="metric">
          <div className="metric-label">Status</div>
          <div className="metric-value">
            <StatusBadge value={p.is_active ? 'active' : 'disabled'} />
          </div>
        </div>
        <div className="metric">
          <div className="metric-label">Phone</div>
          <div className="metric-value small">{p.phone ?? '—'}</div>
        </div>
        <div className="metric">
          <div className="metric-label">Email</div>
          <div className="metric-value small">{p.email ?? '—'}</div>
        </div>
        <div className="metric">
          <div className="metric-label">ID</div>
          <div className="metric-value small mono">{shortId(p.id)}</div>
        </div>
      </div>

      <div className="split">
        <StatusHistory rows={(history ?? []) as HistoryRow[]} />
        <div className="section-stack">
          <AccountStatusPanel
            profileId={p.id}
            name={name}
            isActive={p.is_active}
            deactivationReason={p.deactivation_reason}
            deactivatedAt={p.deactivated_at}
            back={back}
          />
          {d ? (
            <DriverStatusPanel
              driverId={d.id}
              name={name}
              verificationStatus={d.verification_status}
              suspensionReason={d.suspension_reason}
              suspendedAt={d.suspended_at}
              back={back}
            />
          ) : null}
        </div>
      </div>
    </>
  );
}
