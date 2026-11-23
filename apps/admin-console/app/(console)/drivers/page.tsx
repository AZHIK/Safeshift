import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { accountItems, RecordActions } from '@/components/record-actions';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function DriversPage() {
  await requireArea('drivers');
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('drivers')
    .select(
      'id, verification_status, risk_tier, rating, total_trips, total_earnings, is_available, created_at',
    )
    .order('created_at', { ascending: false })
    .limit(100);

  const profiles = await loadProfileSummaries(
    supabase,
    (data ?? []).map((driver) => driver.id),
  );

  const rows = (data ?? []).map((driver) => {
    const profile = profiles.get(driver.id);
    return [
      <div key="n">
        <Link href={`/drivers/${driver.id}`}>
          <strong>{profile?.full_name ?? shortId(driver.id)}</strong>
        </Link>
        <div className="small muted">{profile?.phone ?? profile?.email ?? '—'}</div>
      </div>,
      <StatusBadge key="v" value={driver.verification_status} />,
      <StatusBadge key="a" value={driver.is_available ? 'active' : 'paused'} />,
      <span key="r">{Number(driver.rating ?? 0).toFixed(2)}</span>,
      <span key="t">{driver.total_trips ?? 0}</span>,
      <span key="e" className="small">
        {Number(driver.total_earnings ?? 0).toLocaleString()} TZS
      </span>,
      <span key="k" className="small">
        {driver.risk_tier ?? 'standard'}
      </span>,
      <span key="d" className="small muted">
        {formatDate(driver.created_at)}
      </span>,
    ];
  });
  const actions = (data ?? []).map((driver) => (
    <RecordActions
      key={driver.id}
      table="drivers"
      id={driver.id}
      viewHref={`/drivers/${driver.id}`}
      label={`Actions for ${profiles.get(driver.id)?.full_name ?? 'driver'}`}
      items={accountItems({
        profileId: driver.id,
        isActive: profiles.get(driver.id)?.is_active !== false,
        driver: { suspended: driver.verification_status === 'suspended' },
      })}
    />
  ));

  return (
    <>
      <PageHeader records={['drivers']}
        title="Drivers"
        description="Verification, availability, risk tier, and lifetime performance."
      />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={[
            'Driver',
            'Verification',
            'Availability',
            'Rating',
            'Trips',
            'Earnings',
            'Risk',
            'Joined',
          ]}
          rows={rows}
          actions={actions}
          empty="No drivers found."
        />
      </div>
    </>
  );
}
