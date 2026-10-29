import { togglePromoAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function PromosPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('promos');
  const params = await searchParams;
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('promo_codes')
    .select('id, code, name, discount_type, discount_value, max_discount_amount, min_purchase_amount, currency_code, valid_from, valid_to, total_redemption_limit, per_user_redemption_limit, is_active, promo_redemptions(id)')
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <PageHeader title="Promos" description="Discount codes, validity windows, limits, and redemption volume." />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Code', 'Name', 'Discount', 'Window', 'Limits', 'Redemptions', 'Status', 'Action']}
          rows={(data ?? []).map((promo) => [
            <span className="mono" key="c">{promo.code}</span>,
            promo.name,
            <div key="d">{titleize(promo.discount_type)} · {promo.discount_type === 'percentage' || promo.discount_type === 'capped_percentage' ? `${Number(promo.discount_value)}%` : formatMoney(promo.discount_value, promo.currency_code ?? 'TZS')}<div className="small muted">Min {formatMoney(promo.min_purchase_amount, promo.currency_code ?? 'TZS')}</div></div>,
            <span className="small" key="w">{formatDate(promo.valid_from)}<br />{formatDate(promo.valid_to)}</span>,
            <span className="small" key="l">{promo.total_redemption_limit ?? '∞'} total<br />{promo.per_user_redemption_limit} / user</span>,
            promo.promo_redemptions?.length ?? 0,
            <StatusBadge key="s" value={promo.is_active ? 'active' : 'disabled'} />,
            <form action={togglePromoAction} key="a">
              <input type="hidden" name="promo_id" value={promo.id} />
              <input type="hidden" name="enabled" value={promo.is_active ? 'false' : 'true'} />
              <button className="btn btn-sm" type="submit">{promo.is_active ? 'Disable' : 'Enable'}</button>
            </form>,
          ])}
          empty="No promo codes found."
        />
      </div>
    </>
  );
}
