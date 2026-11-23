import Link from 'next/link';

import { PageHeader } from '@/components/page-header';
import { requireArea } from '@/lib/guard';
import type { PromoForm } from '@/lib/promos/promo';

import { loadPromoLookups } from '../lookups';
import { PromoFormClient } from '../promo-form';

export const dynamic = 'force-dynamic';

export default async function NewPromoPage() {
  await requireArea('promos');
  const lookups = await loadPromoLookups();
  const start = new Date();
  start.setMinutes(0, 0, 0);
  const initial: PromoForm = {
    code: '',
    name: '',
    description: '',
    country_id: lookups.countries.length === 1 ? lookups.countries[0].id : '',
    discount_type: 'percentage',
    discount_value: 10,
    max_discount_amount: null,
    min_purchase_amount: 0,
    currency_code: 'TZS',
    valid_from: start.toISOString(),
    valid_to: new Date(start.getTime() + 30 * 24 * 3600 * 1000).toISOString(),
    total_redemption_limit: null,
    per_user_redemption_limit: 1,
    new_users_only: false,
    applicable_vehicle_type_ids: [],
    applicable_city_ids: [],
    applicable_cargo_type_ids: [],
    is_active: true,
    rules: [],
  };

  return (
    <>
      <PageHeader
        title="New promo"
        actions={
          <Link className="btn" href="/promos">
            All promos
          </Link>
        }
      />
      <PromoFormClient promoId={null} initial={initial} lookups={lookups} codeLocked={false} />
    </>
  );
}
