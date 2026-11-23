import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { tone } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 50;
const TYPES = ['all', 'charge', 'refund', 'partial_refund'];
const STATUSES = ['all', 'succeeded', 'pending', 'initiated', 'failed', 'cancelled'];

type Payment = {
  id: string;
  job_id: string;
  amount: number;
  currency_code: string;
  provider_status: string;
  payment_type: string;
  provider_reference: string | null;
  initiated_at: string;
  refund_of_payment_id: string | null;
  payment_providers: { code?: string } | null;
};
type OpenRefund = {
  id: string;
  payment_id: string;
  amount: number;
  currency_code: string;
  reason: string;
  created_at: string;
};

const pick = (value: unknown, allowed: string[]) =>
  typeof value === 'string' && allowed.includes(value) ? value : 'all';

export default async function PaymentsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('payments');
  const params = await searchParams;
  const type = pick(params.type, TYPES);
  const status = pick(params.status, STATUSES);
  const reference = typeof params.q === 'string' ? params.q.replace(/[,()*%\\]/g, ' ').trim() : '';
  const page = Math.max(1, Number(typeof params.page === 'string' ? params.page : 1) || 1);
  const supabase = await createClient();

  let query = supabase
    .from('payments')
    .select(
      'id, job_id, amount, currency_code, provider_status, payment_type, provider_reference, initiated_at, refund_of_payment_id, payment_providers(code)',
      { count: 'exact' },
    )
    .order('initiated_at', { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
  if (type !== 'all') query = query.eq('payment_type', type);
  if (status !== 'all') query = query.eq('provider_status', status);
  if (reference) query = query.ilike('provider_reference', `%${reference}%`);

  const [{ data, error, count }, { data: openRefunds }] = await Promise.all([
    query,
    supabase
      .from('refunds')
      .select('id, payment_id, amount, currency_code, reason, created_at')
      .eq('status', 'processing')
      .order('created_at')
      .limit(20),
  ]);

  const rows = (data ?? []) as unknown as Payment[];
  const open = (openRefunds ?? []) as OpenRefund[];
  const pages = Math.max(1, Math.ceil((count ?? 0) / PAGE_SIZE));
  const link = (p: number) => {
    const qs = new URLSearchParams();
    if (type !== 'all') qs.set('type', type);
    if (status !== 'all') qs.set('status', status);
    if (reference) qs.set('q', reference);
    qs.set('page', String(p));
    return `/payments?${qs.toString()}`;
  };

  return (
    <>
      <PageHeader records={['payments']} title="Payments" description="Charges and refunds. Open a charge to refund it." />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}

      {open.length > 0 ? (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Refunds waiting to complete ({open.length})</h2>
            <p className="card-sub">
              Processing refunds the provider has not confirmed, including refunds started by cancellations. Mark them
              paid with the transfer reference, or cancel them to return the clawbacks.
            </p>
          </div>
          <DataTable
            columns={['Since', 'Amount', 'Reason']}
            rows={open.map((r) => [
              formatDate(r.created_at),
              formatMoney(r.amount, r.currency_code),
              <span key="r" className="small truncate">
                {r.reason}
              </span>,
            ])}
            actions={open.map((r) => (
              <RecordActions
                key={r.id}
                table="refunds"
                id={r.id}
                items={[{ kind: 'link', label: 'Resolve', href: `/payments/${r.payment_id}` }]}
              />
            ))}
          />
        </div>
      ) : null}

      <div className="card">
        <div className="card-pad config-toolbar">
          <form className="inline" role="search">
            <input className="input" type="search" name="q" defaultValue={reference} placeholder="Provider reference"
              aria-label="Search by provider reference" />
            <select className="input" name="type" defaultValue={type} aria-label="Payment type">
              {TYPES.map((t) => (
                <option key={t} value={t}>
                  {t === 'all' ? 'All types' : titleize(t)}
                </option>
              ))}
            </select>
            <select className="input" name="status" defaultValue={status} aria-label="Status">
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s === 'all' ? 'All statuses' : titleize(s)}
                </option>
              ))}
            </select>
            <button className="btn" type="submit">
              Apply
            </button>
          </form>
        </div>
        <DataTable
          columns={['Payment', 'Type', 'Amount', 'Provider', 'Status', 'Date']}
          empty="No payments match these filters."
          actions={rows.map((p) => (
            <RecordActions
              key={p.id}
              table="payments"
              id={p.id}
              viewHref={`/payments/${p.payment_type === 'charge' ? p.id : (p.refund_of_payment_id ?? p.id)}`}
            />
          ))}
          rows={rows.map((p) => [
            <div key="id">
              <Link href={`/payments/${p.payment_type === 'charge' ? p.id : (p.refund_of_payment_id ?? p.id)}`} className="mono">
                {shortId(p.id)}
              </Link>
              <div className="small muted mono">{p.provider_reference ?? '—'}</div>
            </div>,
            titleize(p.payment_type),
            formatMoney(p.amount, p.currency_code),
            p.payment_providers?.code ?? '—',
            <span key="s" className={`badge badge-${tone(p.provider_status)}`}>
              {titleize(p.provider_status)}
            </span>,
            <span key="d" className="small nowrap">
              {formatDate(p.initiated_at)}
            </span>,
          ])}
        />
        {pages > 1 ? (
          <div className="card-pad inline pagination" style={{ justifyContent: 'space-between' }}>
            {page > 1 ? <Link className="btn btn-sm" href={link(page - 1)}>Newer</Link> : <span />}
            <span className="small muted">
              Page {page} of {pages} · {count} payments
            </span>
            {page < pages ? <Link className="btn btn-sm" href={link(page + 1)}>Older</Link> : <span />}
          </div>
        ) : null}
      </div>
    </>
  );
}
