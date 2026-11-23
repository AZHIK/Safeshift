import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney, titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { tone } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';

import { createPayoutBatchAction } from './actions';

export const dynamic = 'force-dynamic';

type Batch = {
  id: string;
  period_start: string;
  period_end: string;
  status: string;
  total_amount: number;
  currency_code: string;
  driver_count: number;
  created_at: string;
  countries: { name?: string } | null;
};
type Attention = {
  id: string;
  batch_id: string | null;
  driver_id: string;
  net_amount: number;
  currency_code: string;
  status: string;
  hold_reason: string | null;
  failure_reason: string | null;
};

/** Last full Monday–Sunday week, as YYYY-MM-DD. */
function lastWeek(): { from: string; to: string } {
  const today = new Date();
  const day = (today.getUTCDay() + 6) % 7; // Monday = 0
  const end = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - day - 1));
  const start = new Date(end);
  start.setUTCDate(end.getUTCDate() - 6);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return { from: iso(start), to: iso(end) };
}

export default async function PayoutsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('payouts');
  const params = await searchParams;
  const supabase = await createClient();

  const [{ data: batches, error: batchError }, { data: attention }, { data: countries }] = await Promise.all([
    supabase
      .from('payout_batches')
      .select('id, period_start, period_end, status, total_amount, currency_code, driver_count, created_at, countries(name)')
      .order('period_end', { ascending: false })
      .limit(50),
    supabase
      .from('payouts')
      .select('id, batch_id, driver_id, net_amount, currency_code, status, hold_reason, failure_reason')
      .in('status', ['on_hold', 'failed'])
      .order('updated_at', { ascending: false })
      .limit(50),
    supabase.from('countries').select('id, name').eq('is_active', true).order('name'),
  ]);

  const week = lastWeek();
  const needs = (attention ?? []) as Attention[];

  return (
    <>
      <PageHeader title="Payouts" description="Driver settlements. Build a batch for a period, review it, then pay." />
      <Notice searchParams={params} />
      {batchError ? <div className="notice notice-error">{batchError.message}</div> : null}

      <div className="split">
        <div className="section-stack">
          {needs.length > 0 ? (
            <div className="card">
              <div className="card-pad" style={{ paddingBottom: 0 }}>
                <h2 className="card-title">Needs attention ({needs.length})</h2>
                <p className="card-sub">Held or failed payouts. Drivers are waiting for these.</p>
              </div>
              <DataTable
                columns={['Status', 'Net', 'Why', '']}
                rows={needs.map((p) => [
                  <span key="s" className={`badge badge-${tone(p.status)}`}>
                    {titleize(p.status)}
                  </span>,
                  formatMoney(p.net_amount, p.currency_code),
                  <span key="w" className="small">
                    {p.hold_reason ?? p.failure_reason ?? '—'}
                  </span>,
                  p.batch_id ? (
                    <Link key="l" className="btn btn-sm" href={`/payouts/${p.batch_id}`}>
                      Open batch
                    </Link>
                  ) : (
                    <span key="l" />
                  ),
                ])}
              />
            </div>
          ) : null}

          <div className="card">
            <div className="card-pad" style={{ paddingBottom: 0 }}>
              <h2 className="card-title">Batches</h2>
            </div>
            <DataTable
              columns={['Period', 'Country', 'Status', 'Drivers', 'Total', 'Created']}
              empty="No payout batches yet."
              rows={((batches ?? []) as unknown as Batch[]).map((b) => [
                <Link key="p" href={`/payouts/${b.id}`} className="nowrap">
                  {formatDate(b.period_start)} – {formatDate(new Date(new Date(b.period_end).getTime() - 1).toISOString())}
                </Link>,
                b.countries?.name ?? '—',
                <span key="s" className={`badge badge-${tone(b.status)}`}>
                  {titleize(b.status)}
                </span>,
                b.driver_count,
                formatMoney(b.total_amount, b.currency_code),
                <span key="c" className="small nowrap">
                  {formatDate(b.created_at)}
                </span>,
              ])}
            />
          </div>
        </div>

        <div className="card card-pad">
          <h2 className="card-title">New batch</h2>
          <p className="card-sub">
            Collects every driver&apos;s net earnings from completed, unrefunded jobs in the period. Each driver and period
            can only be paid once.
          </p>
          <form action={createPayoutBatchAction} className="form" style={{ marginTop: 8 }}>
            <label className="field">
              Country
              <select className="input" name="country_id" required>
                {(countries ?? []).map((c) => (
                  <option key={String(c.id)} value={String(c.id)}>
                    {String(c.name)}
                  </option>
                ))}
              </select>
            </label>
            <div className="form-grid">
              <label className="field">
                From
                <input className="input" type="date" name="period_start" defaultValue={week.from} required />
              </label>
              <label className="field">
                To (inclusive)
                <input className="input" type="date" name="period_end" defaultValue={week.to} required />
              </label>
            </div>
            <button className="btn btn-primary" type="submit">
              Build batch
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
