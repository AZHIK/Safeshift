import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function PricingPage() {
  await requireArea('pricing');
  const supabase = await createClient();
  const [{ data: tariffs, error: tariffError }, { data: versions, error: versionError }] = await Promise.all([
    supabase
      .from('regulated_tariffs')
      .select('id, name, regulatory_body, tariff_structure, currency_code, effective_from, effective_to, is_active, vehicle_types(name)')
      .order('effective_from', { ascending: false })
      .limit(50),
    supabase
      .from('pricing_plan_versions')
      .select('id, version_number, currency_code, effective_from, effective_to, published_at, pricing_plans(name), pricing_plan_base_rates(base_fare, per_km_rate, per_min_rate, minimum_charge, currency_code)')
      .order('effective_from', { ascending: false })
      .limit(50),
  ]);

  return (
    <>
      <PageHeader title="Pricing & tariffs" description="Regulated LATRA fare frameworks and published pricing plan versions. Price changes are made through the versioned pricing workflow, not by editing live quotes." />
      {tariffError ? <div className="notice notice-error">{tariffError.message}</div> : null}
      {versionError ? <div className="notice notice-error">{versionError.message}</div> : null}
      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Regulated tariffs</h2>
            <p className="card-sub">Legal fare bands and their effective windows.</p>
          </div>
          <DataTable
            columns={['Tariff', 'Regulator', 'Structure', 'Vehicle type', 'Effective', 'Status']}
            rows={(tariffs ?? []).map((tariff) => {
              const vehicle = tariff.vehicle_types as { name?: string } | null;
              return [
                <div key="n"><strong>{tariff.name}</strong><div className="small muted">{tariff.currency_code}</div></div>,
                tariff.regulatory_body,
                titleize(tariff.tariff_structure),
                vehicle?.name ?? 'All goods vehicles',
                <span className="small" key="e">{formatDate(tariff.effective_from)}<br />{tariff.effective_to ? formatDate(tariff.effective_to) : 'Open-ended'}</span>,
                <StatusBadge key="s" value={tariff.is_active ? 'active' : 'disabled'} />,
              ];
            })}
            empty="No regulated tariffs found."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Pricing plan versions</h2>
            <p className="card-sub">Published base rates. Historical versions remain immutable.</p>
          </div>
          <DataTable
            columns={['Plan', 'Version', 'Base fare', 'Per km', 'Per min', 'Minimum', 'Effective', 'Published']}
            rows={(versions ?? []).map((version) => {
              const plan = version.pricing_plans as { name?: string } | null;
              const rates = (version.pricing_plan_base_rates as { base_fare?: number; per_km_rate?: number; per_min_rate?: number; minimum_charge?: number; currency_code?: string }[] | null)?.[0];
              return [
                plan?.name ?? 'Pricing plan',
                `v${version.version_number}`,
                formatMoney(rates?.base_fare, rates?.currency_code ?? version.currency_code),
                formatMoney(rates?.per_km_rate, rates?.currency_code ?? version.currency_code),
                formatMoney(rates?.per_min_rate, rates?.currency_code ?? version.currency_code),
                formatMoney(rates?.minimum_charge, rates?.currency_code ?? version.currency_code),
                <span className="small" key="e">{formatDate(version.effective_from)}</span>,
                <span className="small muted" key="p">{formatDate(version.published_at)}</span>,
              ];
            })}
            empty="No pricing plan versions found."
          />
        </div>
      </div>
    </>
  );
}
