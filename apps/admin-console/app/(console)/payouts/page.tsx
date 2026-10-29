import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, shortId } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function PayoutsPage() {
  await requireArea('payouts');
  const supabase = await createClient();
  const [{ data: batches, error: batchError }, { data: payouts, error: payoutError }] = await Promise.all([
    supabase.from('payout_batches').select('id, period_start, period_end, status, total_amount, currency_code, driver_count, created_at').order('created_at', { ascending: false }).limit(25),
    supabase.from('payouts').select('id, driver_id, amount, net_amount, currency_code, status, period_start, period_end, provider_reference').order('created_at', { ascending: false }).limit(50),
  ]);

  return (
    <>
      <PageHeader title="Payouts" description="Driver settlement batches and individual payout items. Phase 5 refund and compensation semantics remain a separate finance decision." />
      {batchError ? <div className="notice notice-error">{batchError.message}</div> : null}
      {payoutError ? <div className="notice notice-error">{payoutError.message}</div> : null}
      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Batches</h2>
            <p className="card-sub">Weekly payout runs.</p>
          </div>
          <DataTable
            columns={['Batch', 'Period', 'Status', 'Drivers', 'Total', 'Created']}
            rows={(batches ?? []).map((batch) => [
              <span className="mono" key="b">{shortId(batch.id)}</span>,
              <span className="small" key="p">{formatDate(batch.period_start)} → {formatDate(batch.period_end)}</span>,
              <StatusBadge key="s" value={batch.status} />,
              batch.driver_count ?? 0,
              formatMoney(batch.total_amount, batch.currency_code ?? 'TZS'),
              <span className="small muted" key="c">{formatDate(batch.created_at)}</span>,
            ])}
            empty="No payout batches."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Payout items</h2>
            <p className="card-sub">Driver-level settlement lines.</p>
          </div>
          <DataTable
            columns={['Payout', 'Driver', 'Gross', 'Net', 'Status', 'Period', 'Provider ref']}
            rows={(payouts ?? []).map((payout) => [
              <span className="mono" key="p">{shortId(payout.id)}</span>,
              <span className="mono small" key="d">{shortId(payout.driver_id)}</span>,
              formatMoney(payout.amount, payout.currency_code ?? 'TZS'),
              formatMoney(payout.net_amount, payout.currency_code ?? 'TZS'),
              <StatusBadge key="s" value={payout.status} />,
              <span className="small" key="pe">{formatDate(payout.period_start)} → {formatDate(payout.period_end)}</span>,
              <span className="mono small" key="r">{payout.provider_reference ?? '—'}</span>,
            ])}
            empty="No payout items."
          />
        </div>
      </div>
    </>
  );
}
