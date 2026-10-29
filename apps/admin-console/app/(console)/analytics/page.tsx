import { MetricCard } from '@/components/metric-card';
import { PageHeader } from '@/components/page-header';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function AnalyticsPage() {
  await requireArea('analytics');
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('daily_metrics')
    .select('metric_date, jobs_created, jobs_completed, jobs_cancelled, gross_booking_value, net_revenue, active_customers, active_drivers, new_customers, new_drivers, avg_acceptance_rate, avg_completion_minutes, avg_cancellation_rate, avg_rating, currency_code')
    .order('metric_date', { ascending: false })
    .limit(30);

  const rows = [...(data ?? [])].reverse();
  const totals = rows.reduce(
    (acc, row) => ({
      jobs: acc.jobs + Number(row.jobs_created ?? 0),
      completed: acc.completed + Number(row.jobs_completed ?? 0),
      cancelled: acc.cancelled + Number(row.jobs_cancelled ?? 0),
      gbv: acc.gbv + Number(row.gross_booking_value ?? 0),
      net: acc.net + Number(row.net_revenue ?? 0),
    }),
    { jobs: 0, completed: 0, cancelled: 0, gbv: 0, net: 0 },
  );
  const maxJobs = Math.max(1, ...rows.map((row) => Number(row.jobs_created ?? 0)));
  const currency = rows[0]?.currency_code ?? 'TZS';

  return (
    <>
      <PageHeader title="Analytics" description="Daily marketplace metrics for the last 30 recorded days. Zone-level and driver-level drilldowns use the same source tables." />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <MetricCard label="Jobs created" value={totals.jobs} note="Last 30 recorded days" />
        <MetricCard label="Completed" value={totals.completed} note={`${totals.jobs ? Math.round((totals.completed / totals.jobs) * 100) : 0}% completion`} />
        <MetricCard label="GBV" value={formatMoney(totals.gbv, currency)} />
        <MetricCard label="Net revenue" value={formatMoney(totals.net, currency)} />
      </div>
      <div className="card card-pad" style={{ marginBottom: 16 }}>
        <h2 className="card-title">Daily job volume</h2>
        <p className="card-sub">Bars scale to the busiest day in this window.</p>
        <div style={{ display: 'flex', alignItems: 'end', gap: 5, height: 130, marginTop: 16 }}>
          {rows.map((row) => (
            <div key={row.metric_date} title={`${row.metric_date}: ${row.jobs_created} jobs`} style={{ flex: 1, height: `${Math.max(4, (Number(row.jobs_created ?? 0) / maxJobs) * 100)}%`, background: 'linear-gradient(180deg, #2f8cff, #0b63d6)', borderRadius: '5px 5px 2px 2px' }} />
          ))}
          {rows.length === 0 ? <span className="muted">No daily metrics recorded yet.</span> : null}
        </div>
      </div>
      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>{['Date', 'Created', 'Completed', 'Cancelled', 'GBV', 'Net', 'Customers', 'Drivers', 'New users', 'Acceptance', 'Avg mins', 'Rating'].map((column) => <th key={column}>{column}</th>)}</tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.metric_date}>
                  <td className="small nowrap">{formatDate(row.metric_date)}</td>
                  <td>{row.jobs_created}</td>
                  <td>{row.jobs_completed}</td>
                  <td>{row.jobs_cancelled}</td>
                  <td className="small">{formatMoney(row.gross_booking_value, row.currency_code ?? currency)}</td>
                  <td className="small">{formatMoney(row.net_revenue, row.currency_code ?? currency)}</td>
                  <td>{row.active_customers}</td>
                  <td>{row.active_drivers}</td>
                  <td className="small">+{row.new_customers} / +{row.new_drivers}</td>
                  <td className="small">{row.avg_acceptance_rate == null ? '—' : `${Math.round(Number(row.avg_acceptance_rate) * 100)}%`}</td>
                  <td className="small">{row.avg_completion_minutes ?? '—'}</td>
                  <td className="small">{row.avg_rating == null ? '—' : Number(row.avg_rating).toFixed(2)}</td>
                </tr>
              ))}
              {rows.length === 0 ? <tr><td colSpan={12} className="table-empty">No daily metrics recorded yet.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
