import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { MetricCard } from '@/components/metric-card';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { RealtimeDashboard } from '@/components/realtime-dashboard';
import { StatusBadge } from '@/components/status-badge';
import { getAdminSession } from '@/lib/auth';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const session = await getAdminSession();
  if (!session) return null;
  const supabase = await createClient();

  if (session.role === 'fleet_owner') {
    const { data: fleets } = await supabase
      .from('fleets')
      .select('id, name, verified_at, is_active, fleet_vehicles(vehicle_id), fleet_members(driver_id)')
      .eq('owner_profile_id', session.userId);
    const rows = (fleets ?? []).map((fleet) => [
      fleet.name,
      <StatusBadge key="v" value={fleet.verified_at ? 'verified' : 'pending'} />,
      `${fleet.fleet_vehicles?.length ?? 0}`,
      `${fleet.fleet_members?.length ?? 0}`,
      <Link className="btn btn-sm" href="/fleets" key="l">Open fleet</Link>,
    ]);
    return (
      <>
        <PageHeader
          title={`Fleet overview · ${session.name}`}
          description="Your fleet vehicles, assigned drivers, and earnings. Fleet owners cannot access other marketplace data."
        />
        <Notice searchParams={params} />
        <div className="card card-pad">
          <DataTable
            columns={['Fleet', 'Verification', 'Vehicles', 'Drivers', '']}
            rows={rows}
            empty="No fleet is linked to your account yet. Contact SafeShift operations."
          />
        </div>
      </>
    );
  }

  const [{ data: metrics }, { data: activity }, { data: alerts }, { data: queue }] =
    await Promise.all([
      supabase.from('admin_dashboard_metrics').select('*').maybeSingle(),
      supabase.rpc('admin_recent_activity', { p_limit: 8 }),
      supabase
        .from('trip_alerts')
        .select('id, alert_type, status, created_at, job_id, profile_id')
        .in('status', ['open', 'acknowledged'])
        .order('created_at', { ascending: false })
        .limit(5),
      supabase
        .from('verification_requests')
        .select('id, request_type, status, submitted_at, driver_id, vehicle_id, business_account_id')
        .in('status', ['pending', 'in_review'])
        .order('submitted_at', { ascending: true })
        .limit(5),
    ]);

  return (
    <>
      <PageHeader
        title="Operations dashboard"
        description="A live view of marketplace health, trust & safety queues, and support load."
        actions={<RealtimeDashboard />}
      />
      <Notice searchParams={params} />
      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <MetricCard label="Active jobs" value={metrics?.active_jobs ?? 0} note="In progress across all zones" />
        <MetricCard label="Open SOS" value={metrics?.open_sos_alerts ?? 0} note="Needs on-call acknowledgement" />
        <MetricCard label="Pending verifications" value={metrics?.pending_verifications ?? 0} note="Driver, vehicle, and business" />
        <MetricCard label="Open disputes" value={metrics?.open_disputes ?? 0} note="Customer and driver cases" />
      </div>
      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <MetricCard label="Jobs · 24h" value={metrics?.jobs_last_24h ?? 0} />
        <MetricCard label="GBV · 7d" value={formatMoney(metrics?.gbv_last_7d)} />
        <MetricCard label="Verified drivers" value={metrics?.verified_drivers ?? 0} />
        <MetricCard label="Active users" value={metrics?.active_users ?? 0} />
      </div>
      <div className="split">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Recent activity</h2>
            <p className="card-sub">Admin actions and security audit events.</p>
          </div>
          <DataTable
            columns={['Actor', 'Action', 'Entity', 'When']}
            rows={((activity ?? []) as Array<{ actor_name?: string | null; action?: string; entity_type?: string | null; entity_id?: string | null; created_at?: string }>).map((row) => [
              row.actor_name ?? 'System',
              <span key="a">{titleize(row.action)}</span>,
              <span className="mono" key="e">{row.entity_type ?? '—'} {shortId(row.entity_id)}</span>,
              <span className="small muted" key="d">{formatDate(row.created_at)}</span>,
            ])}
            empty="No activity recorded yet."
          />
        </div>
        <div className="section-stack">
          <div className="card">
            <div className="card-pad" style={{ paddingBottom: 0 }}>
              <h2 className="card-title">SOS & safety alerts</h2>
              <p className="card-sub">Acknowledge from Incidents & SOS.</p>
            </div>
            <DataTable
              columns={['Type', 'Status', 'When']}
              rows={(alerts ?? []).map((row) => [
                titleize(row.alert_type),
                <StatusBadge key="s" value={row.status} />,
                <span className="small muted" key="d">{formatDate(row.created_at)}</span>,
              ])}
              empty="No open safety alerts."
            />
            <div className="card-pad" style={{ paddingTop: 0 }}>
              <Link className="btn btn-sm" href="/incidents">Open safety desk</Link>
            </div>
          </div>
          <div className="card">
            <div className="card-pad" style={{ paddingBottom: 0 }}>
              <h2 className="card-title">Verification queue</h2>
              <p className="card-sub">Oldest submissions first.</p>
            </div>
            <DataTable
              columns={['Type', 'Status', 'Submitted']}
              rows={(queue ?? []).map((row) => [
                titleize(row.request_type),
                <StatusBadge key="s" value={row.status} />,
                <span className="small muted" key="d">{formatDate(row.submitted_at)}</span>,
              ])}
              empty="The verification queue is clear."
            />
            <div className="card-pad" style={{ paddingTop: 0 }}>
              <Link className="btn btn-sm" href="/verifications">Review queue</Link>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
