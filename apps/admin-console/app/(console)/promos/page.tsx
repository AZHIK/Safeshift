import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { PROMO_STATUS, describeDiscount, promoStatus, type PromoStatus } from '@/lib/promos/promo';
import { createClient } from '@/lib/supabase/server';

import { setPromoActiveAction } from './actions';

export const dynamic = 'force-dynamic';

type PromoRow = {
  id: string;
  code: string;
  name: string;
  discount_type: string;
  discount_value: number;
  max_discount_amount: number | null;
  min_purchase_amount: number;
  currency_code: string | null;
  valid_from: string;
  valid_to: string;
  total_redemption_limit: number | null;
  per_user_redemption_limit: number;
  is_active: boolean;
};
type Summary = { promo_code_id: string; redemptions: number; total_discount: number };

const STATUS_FILTERS: (PromoStatus | 'all')[] = ['all', 'live', 'scheduled', 'inactive', 'used_up', 'expired'];

export default async function PromosPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('promos');
  const params = await searchParams;
  const query = typeof params.q === 'string' ? params.q.replace(/[,()*%\\]/g, ' ').trim() : '';
  const statusFilter =
    typeof params.status === 'string' && (STATUS_FILTERS as string[]).includes(params.status) ? params.status : 'all';
  const supabase = await createClient();

  let promoQuery = supabase
    .from('promo_codes')
    .select(
      'id, code, name, discount_type, discount_value, max_discount_amount, min_purchase_amount, currency_code, valid_from, valid_to, total_redemption_limit, per_user_redemption_limit, is_active',
    )
    .order('created_at', { ascending: false })
    .limit(500);
  if (query) promoQuery = promoQuery.or(`code.ilike.%${query}%,name.ilike.%${query}%`);

  const [{ data, error }, { data: summaries, error: summaryError }] = await Promise.all([
    promoQuery,
    supabase.rpc('admin_promo_summaries'),
  ]);

  const byPromo = new Map<string, Summary>();
  for (const s of (summaries ?? []) as Summary[]) byPromo.set(String(s.promo_code_id), s);

  const now = new Date();
  const rows = ((data ?? []) as PromoRow[])
    .map((promo) => {
      const summary = byPromo.get(promo.id);
      const used = Number(summary?.redemptions ?? 0);
      return { promo, summary, used, status: promoStatus(promo, used, now) };
    })
    .filter((r) => statusFilter === 'all' || r.status === statusFilter);

  return (
    <>
      <PageHeader records={['promos']}
        title="Promos"
        description="Discount codes customers enter at booking. A promo applies only while live, within its limits and rules."
        actions={
          <Link className="btn btn-primary" href="/promos/new">
            New promo
          </Link>
        }
      />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      {summaryError ? <div className="notice notice-error">{summaryError.message}</div> : null}

      <div className="card">
        <div className="card-pad config-toolbar">
          <form className="inline" role="search">
            <input
              className="input"
              type="search"
              name="q"
              defaultValue={query}
              placeholder="Search by code or name"
              aria-label="Search promos"
            />
            <select className="input" name="status" defaultValue={statusFilter} aria-label="Filter by status">
              {STATUS_FILTERS.map((s) => (
                <option key={s} value={s}>
                  {s === 'all' ? 'All statuses' : PROMO_STATUS[s].label}
                </option>
              ))}
            </select>
            <button className="btn" type="submit">
              Apply
            </button>
          </form>
        </div>
        <DataTable
          columns={['Code', 'Discount', 'Valid', 'Used', 'Discount given', 'Status', '']}
          empty={query || statusFilter !== 'all' ? 'No promos match these filters.' : 'No promo codes yet.'}
          rows={rows.map(({ promo, summary, used, status }) => [
            <div key="c">
              <Link href={`/promos/${promo.id}`} className="mono">
                <strong>{promo.code}</strong>
              </Link>
              <div className="small muted">{promo.name}</div>
            </div>,
            <div key="d">
              {describeDiscount(promo, (v, c) => formatMoney(v, c))}
              {Number(promo.min_purchase_amount) > 0 ? (
                <div className="small muted">
                  Fare from {formatMoney(promo.min_purchase_amount, promo.currency_code?.trim() || 'TZS')}
                </div>
              ) : null}
            </div>,
            <span key="w" className="small nowrap">
              {formatDate(promo.valid_from)}
              <br />
              {formatDate(promo.valid_to)}
            </span>,
            <span key="u" className="small nowrap">
              {used} / {promo.total_redemption_limit ?? '∞'}
              <br />
              <span className="muted">{promo.per_user_redemption_limit} per customer</span>
            </span>,
            formatMoney(Number(summary?.total_discount ?? 0), promo.currency_code?.trim() || 'TZS'),
            <span key="s" className={`badge badge-${PROMO_STATUS[status].tone}`}>
              {PROMO_STATUS[status].label}
            </span>,
            <form action={setPromoActiveAction} key="a">
              <input type="hidden" name="promo_id" value={promo.id} />
              <input type="hidden" name="active" value={promo.is_active ? 'false' : 'true'} />
              <button className="btn btn-sm" type="submit">
                {promo.is_active ? 'Pause' : 'Resume'}
              </button>
            </form>,
          ])}
        />
      </div>
    </>
  );
}
