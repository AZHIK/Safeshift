import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ConfirmSubmit } from '@/components/confirm-submit';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney, shortId } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { PROMO_STATUS, describeDiscount, formFromPromo, promoStatus } from '@/lib/promos/promo';
import { createClient } from '@/lib/supabase/server';

import { deletePromoAction, setPromoActiveAction } from '../actions';
import { loadPromoLookups } from '../lookups';
import { PromoFormClient } from '../promo-form';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 25;

type Redemption = {
  id: string;
  redeemed_at: string;
  discount_amount: number;
  currency_code: string;
  job_id: string | null;
  customer_name: string;
  total_count: number;
};
type Summary = {
  promo_code_id: string;
  redemptions: number;
  unique_customers: number;
  total_discount: number;
  last_redeemed_at: string | null;
};

export default async function PromoDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('promos');
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const page = Math.max(1, Number(typeof query.page === 'string' ? query.page : 1) || 1);
  const supabase = await createClient();

  const [{ data: promo, error }, { data: summaries }, { data: history, error: historyError }, lookups] =
    await Promise.all([
      supabase.from('promo_codes').select('*, promo_code_eligibility_rules(*)').eq('id', id).maybeSingle(),
      supabase.rpc('admin_promo_summaries'),
      supabase.rpc('admin_promo_redemptions', {
        p_promo_id: id,
        p_limit: PAGE_SIZE,
        p_offset: (page - 1) * PAGE_SIZE,
      }),
      loadPromoLookups(),
    ]);
  if (error) {
    return (
      <>
        <PageHeader title="Promo" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!promo) notFound();

  const summary = ((summaries ?? []) as Summary[]).find((s) => String(s.promo_code_id) === id);
  const used = Number(summary?.redemptions ?? 0);
  const status = promoStatus(promo, used);
  const currency = String(promo.currency_code ?? '').trim() || 'TZS';
  const rows = (history ?? []) as Redemption[];
  const total = Number(rows[0]?.total_count ?? 0);
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <>
      <PageHeader
        title={promo.code}
        description={`${promo.name} · ${describeDiscount(promo, (v, c) => formatMoney(v, c))}`}
        actions={
          <>
            <Link className="btn" href="/promos">
              All promos
            </Link>
            <form action={setPromoActiveAction}>
              <input type="hidden" name="promo_id" value={promo.id} />
              <input type="hidden" name="back" value="detail" />
              <input type="hidden" name="active" value={promo.is_active ? 'false' : 'true'} />
              <button className="btn" type="submit">
                {promo.is_active ? 'Pause' : 'Resume'}
              </button>
            </form>
          </>
        }
      />
      <Notice searchParams={query} />

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <div className="metric">
          <div className="metric-label">Status</div>
          <div className="metric-value">
            <span className={`badge badge-${PROMO_STATUS[status].tone}`}>{PROMO_STATUS[status].label}</span>
          </div>
          <div className="metric-note">
            {formatDate(promo.valid_from)} – {formatDate(promo.valid_to)}
          </div>
        </div>
        <div className="metric">
          <div className="metric-label">Uses</div>
          <div className="metric-value">
            {used} / {promo.total_redemption_limit ?? '∞'}
          </div>
          <div className="metric-note">{Number(summary?.unique_customers ?? 0)} customers</div>
        </div>
        <div className="metric">
          <div className="metric-label">Discount given</div>
          <div className="metric-value">{formatMoney(Number(summary?.total_discount ?? 0), currency)}</div>
          <div className="metric-note">
            {used > 0 ? `avg ${formatMoney(Number(summary?.total_discount ?? 0) / used, currency)}` : 'not used yet'}
          </div>
        </div>
        <div className="metric">
          <div className="metric-label">Last used</div>
          <div className="metric-value small">{summary?.last_redeemed_at ? formatDate(summary.last_redeemed_at) : '—'}</div>
        </div>
      </div>

      <div className="split">
        <PromoFormClient promoId={promo.id} initial={formFromPromo(promo)} lookups={lookups} codeLocked={used > 0} />

        <div className="section-stack">
          <div className="card">
            <div className="card-pad" style={{ paddingBottom: 0 }}>
              <h2 className="card-title">Redemptions</h2>
              <p className="card-sub">{total} in total.</p>
            </div>
            {historyError ? <div className="notice notice-error">{historyError.message}</div> : null}
            <DataTable
              columns={['When', 'Customer', 'Discount', 'Job']}
              empty="Not redeemed yet."
              rows={rows.map((r) => [
                <span key="w" className="nowrap small">
                  {formatDate(r.redeemed_at)}
                </span>,
                r.customer_name,
                formatMoney(r.discount_amount, r.currency_code),
                r.job_id ? (
                  <span key="j" className="mono small">
                    {shortId(r.job_id)}
                  </span>
                ) : (
                  '—'
                ),
              ])}
            />
            {pages > 1 ? (
              <div className="card-pad pagination inline" style={{ justifyContent: 'space-between' }}>
                {page > 1 ? (
                  <Link className="btn btn-sm" href={`/promos/${promo.id}?page=${page - 1}`}>
                    Newer
                  </Link>
                ) : (
                  <span />
                )}
                <span className="small muted">
                  Page {page} of {pages}
                </span>
                {page < pages ? (
                  <Link className="btn btn-sm" href={`/promos/${promo.id}?page=${page + 1}`}>
                    Older
                  </Link>
                ) : (
                  <span />
                )}
              </div>
            ) : null}
          </div>

          <div className="card card-pad">
            <h2 className="card-title">Delete promo</h2>
            <p className="small muted">
              {used > 0
                ? 'Redeemed promos are kept for the record. Pause it instead.'
                : 'Only promos that were never redeemed can be deleted.'}
            </p>
            {used === 0 ? (
              <form action={deletePromoAction}>
                <input type="hidden" name="promo_id" value={promo.id} />
                <ConfirmSubmit message={`Delete promo ${promo.code}? This cannot be undone.`}>Delete promo</ConfirmSubmit>
              </form>
            ) : null}
          </div>
        </div>
      </div>
    </>
  );
}
