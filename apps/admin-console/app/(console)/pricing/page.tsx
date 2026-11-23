import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { formatDate, formatMoney } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { versionStatus, type VersionTiming } from '@/lib/pricing/draft';
import { createClient } from '@/lib/supabase/server';

import { NewPlanForm } from './new-plan-form';

export const dynamic = 'force-dynamic';

type Named = { name?: string | null } | null;
type VersionRow = VersionTiming & {
  id: string;
  version_number: number;
  currency_code: string;
  pricing_plan_base_rates: { base_fare: number; per_km_rate: number; per_min_rate: number }[] | null;
};
type PlanRow = {
  id: string;
  code: string;
  name: string;
  is_active: boolean;
  countries: Named;
  cities: Named;
  vehicle_types: Named;
  pricing_plan_versions: VersionRow[] | null;
};
type TariffRow = {
  id: string;
  name: string;
  regulatory_body: string | null;
  tariff_structure: string | null;
  currency_code: string;
  effective_from: string;
  effective_to: string | null;
  is_active: boolean;
  vehicle_types: Named;
};

export default async function PricingPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('pricing');
  const params = await searchParams;
  // Characters with meaning in a PostgREST or() filter are dropped, so a search
  // cannot change the filter itself.
  const query = typeof params.q === 'string' ? params.q.replace(/[,()*%\\]/g, ' ').trim() : '';
  const supabase = await createClient();

  let planQuery = supabase
    .from('pricing_plans')
    .select(
      'id, code, name, is_active, countries(name), cities(name), vehicle_types(name), pricing_plan_versions(id, version_number, currency_code, effective_from, effective_to, published_at, pricing_plan_base_rates(base_fare, per_km_rate, per_min_rate))',
    )
    .order('name');
  if (query) planQuery = planQuery.or(`name.ilike.%${query}%,code.ilike.%${query}%`);

  const [
    { data: plans, error: planError },
    { data: tariffs, error: tariffError },
    { data: countries },
    { data: cities },
    { data: vehicleTypes },
  ] = await Promise.all([
    planQuery,
    supabase
      .from('regulated_tariffs')
      .select(
        'id, name, regulatory_body, tariff_structure, currency_code, effective_from, effective_to, is_active, vehicle_types(name)',
      )
      .order('effective_from', { ascending: false })
      .limit(50),
    supabase.from('countries').select('id, name').eq('is_active', true).order('name'),
    supabase.from('cities').select('id, name, country_id').eq('is_active', true).order('name'),
    supabase.from('vehicle_types').select('id, name').eq('is_active', true).order('display_order'),
  ]);

  const now = new Date();
  const rows = ((plans ?? []) as unknown as PlanRow[]).map((plan) => {
    const versions = plan.pricing_plan_versions ?? [];
    const withStatus = versions.map((v) => ({ ...v, status: versionStatus(v, now) }));
    const active = withStatus.find((v) => v.status === 'active');
    const draft = withStatus.find((v) => v.status === 'draft');
    const scheduled = withStatus.find((v) => v.status === 'scheduled');
    const rates = active?.pricing_plan_base_rates?.[0];
    return { plan, active, draft, scheduled, rates };
  });

  return (
    <>
      <PageHeader records={['pricing', 'tariffs']}
        title="Pricing & tariffs"
        description="Plans price every booking; there is no fallback price. Rates change through drafts, which you can preview, schedule and roll back."
        actions={
          <NewPlanForm
            countries={(countries ?? []).map((c) => ({ id: String(c.id), name: String(c.name) }))}
            cities={(cities ?? []).map((c) => ({
              id: String(c.id),
              name: String(c.name),
              country_id: String(c.country_id),
            }))}
            vehicleTypes={(vehicleTypes ?? []).map((v) => ({ id: String(v.id), name: String(v.name) }))}
          />
        }
      />
      <Notice searchParams={params} />
      {planError ? <div className="notice notice-error">{planError.message}</div> : null}
      {tariffError ? <div className="notice notice-error">{tariffError.message}</div> : null}

      <div className="card">
        <div className="card-pad config-toolbar">
          <form className="inline" role="search">
            <input
              className="input"
              type="search"
              name="q"
              defaultValue={query}
              placeholder="Search by name or code"
              aria-label="Search pricing plans"
            />
            <button className="btn" type="submit">
              Search
            </button>
          </form>
        </div>
        <DataTable
          columns={['Plan', 'Scope', 'Active version', 'Base · per km · per min', 'Pending', 'Status']}
          empty={query ? 'No plans match your search.' : 'No pricing plans yet. Bookings cannot be priced.'}
          rows={rows.map(({ plan, active, draft, scheduled, rates }) => [
            <div key="plan">
              <Link href={`/pricing/${plan.id}`}>
                <strong>{plan.name}</strong>
              </Link>
              <div className="small muted mono">{plan.code}</div>
            </div>,
            <div key="scope">
              {plan.cities?.name ?? '—'}
              <div className="small muted">
                {plan.countries?.name ?? ''} · {plan.vehicle_types?.name ?? 'Any vehicle'}
              </div>
            </div>,
            active ? (
              <div key="active">
                v{active.version_number}
                <div className="small muted">since {formatDate(active.effective_from)}</div>
              </div>
            ) : (
              <span key="active" className="badge badge-red">
                None in force
              </span>
            ),
            rates && active ? (
              <span key="rates" className="nowrap">
                {formatMoney(rates.base_fare, active.currency_code)} · {formatMoney(rates.per_km_rate, active.currency_code)}{' '}
                · {formatMoney(rates.per_min_rate, active.currency_code)}
              </span>
            ) : (
              '—'
            ),
            <div key="pending" className="chip-list">
              {scheduled ? (
                <span className="badge badge-violet">
                  v{scheduled.version_number} from {formatDate(scheduled.effective_from)}
                </span>
              ) : null}
              {draft ? <span className="badge badge-amber">Draft v{draft.version_number}</span> : null}
              {!scheduled && !draft ? <span className="muted">—</span> : null}
            </div>,
            <StatusBadge key="status" value={plan.is_active ? 'active' : 'disabled'} />,
          ])}
        />
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <div className="card-pad" style={{ paddingBottom: 0 }}>
          <h2 className="card-title">Regulated tariffs</h2>
          <p className="card-sub">Legal fare bands (e.g. LATRA). A plan version linked to a tariff is capped by it.</p>
        </div>
        <DataTable
          columns={['Tariff', 'Regulator', 'Structure', 'Vehicle type', 'Effective', 'Status']}
          rows={((tariffs ?? []) as unknown as TariffRow[]).map((tariff) => [
            <div key="n">
              <strong>{tariff.name}</strong>
              <div className="small muted">{tariff.currency_code}</div>
            </div>,
            tariff.regulatory_body ?? '—',
            tariff.tariff_structure ?? '—',
            tariff.vehicle_types?.name ?? 'Any',
            <span key="e" className="nowrap">
              {formatDate(tariff.effective_from)}
              {tariff.effective_to ? ` – ${formatDate(tariff.effective_to)}` : ''}
            </span>,
            <StatusBadge key="s" value={tariff.is_active ? 'active' : 'disabled'} />,
          ])}
        />
      </div>
    </>
  );
}
