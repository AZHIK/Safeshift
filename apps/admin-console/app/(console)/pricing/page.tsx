import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { PricingClient } from './pricing-client';

export const dynamic = 'force-dynamic';

export default async function PricingPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('pricing');
  const params = await searchParams;
  const supabase = await createClient();
  const [
    { data: tariffs, error: tariffError },
    { data: versions, error: versionError },
    { data: countries },
    { data: cities },
    { data: vehicleTypes },
  ] = await Promise.all([
    supabase
      .from('regulated_tariffs')
      .select(
        'id, name, regulatory_body, tariff_structure, currency_code, effective_from, effective_to, is_active, vehicle_types(name)',
      )
      .order('effective_from', { ascending: false })
      .limit(50),
    supabase
      .from('pricing_plan_versions')
      .select(
        'id, version_number, currency_code, effective_from, effective_to, published_at, pricing_plans(id, name, code, is_active, countries(name), cities(name), vehicle_types(name)), pricing_plan_base_rates(base_fare, per_km_rate, per_min_rate, minimum_charge, vat_rate, currency_code)',
      )
      .order('effective_from', { ascending: false })
      .limit(50),
    supabase.from('countries').select('id, name').eq('is_active', true).order('name'),
    supabase.from('cities').select('id, name, country_id').eq('is_active', true).order('name'),
    supabase.from('vehicle_types').select('id, name, code').eq('is_active', true).order('display_order'),
  ]);

  const plans = (versions ?? []).map((version: any) => {
    const plan = version.pricing_plans as {
      id?: string;
      name?: string;
      code?: string;
      is_active?: boolean;
      countries?: { name?: string };
      cities?: { name?: string };
      vehicle_types?: { name?: string };
    } | null;
    const rates = (
      version.pricing_plan_base_rates as
        | {
            base_fare?: number;
            per_km_rate?: number;
            per_min_rate?: number;
            minimum_charge?: number;
            vat_rate?: number;
            currency_code?: string;
          }[]
        | null
    )?.[0];
    const currency = rates?.currency_code ?? version.currency_code ?? 'TZS';
    return {
      id: String(plan?.id ?? version.id),
      name: plan?.name ?? 'Pricing plan',
      code: plan?.code ?? '',
      isActive: Boolean(plan?.is_active),
      country: plan?.countries?.name ?? '',
      city: plan?.cities?.name ?? '',
      vehicle: plan?.vehicle_types?.name ?? '',
      currency,
      baseFare: Number(rates?.base_fare ?? 0),
      perKm: Number(rates?.per_km_rate ?? 0),
      perMin: Number(rates?.per_min_rate ?? 0),
      minimum: Number(rates?.minimum_charge ?? 0),
      vat: Number(rates?.vat_rate ?? 0.18),
    };
  });

  // De-duplicate by plan id (latest version wins because of ordering).
  const byId = new Map<string, (typeof plans)[number]>();
  for (const p of plans) byId.set(p.id, p);
  const uniquePlans = Array.from(byId.values());

  return (
    <>
      <PageHeader
        title="Pricing & tariffs"
        description="Regulated LATRA fare frameworks and published pricing plan versions. Create a pricing plan to make bookings priceable; there is no fallback price."
      />
      <Notice searchParams={params} />
      {tariffError ? <div className="notice notice-error">{tariffError.message}</div> : null}
      {versionError ? <div className="notice notice-error">{versionError.message}</div> : null}

      <PricingClient
        plans={uniquePlans}
        countries={(countries ?? []).map((c: any) => ({ id: String(c.id), name: String(c.name) }))}
        cities={(cities ?? []).map((c: any) => ({
          id: String(c.id),
          name: String(c.name),
          country_id: String(c.country_id),
        }))}
        vehicleTypes={(vehicleTypes ?? []).map((v: any) => ({ id: String(v.id), name: String(v.name) }))}
      />

      <div className="card" style={{ marginTop: 16 }}>
        <div className="card-pad" style={{ paddingBottom: 0 }}>
          <h2 className="card-title">Regulated tariffs</h2>
          <p className="card-sub">Legal fare bands and their effective windows.</p>
        </div>
        <DataTable
          columns={['Tariff', 'Regulator', 'Structure', 'Vehicle type', 'Effective', 'Status']}
          rows={(tariffs ?? []).map((tariff: any) => {
            const vehicle = tariff.vehicle_types as { name?: string } | null;
            return [
              <div key="n">
                <strong>{tariff.name}</strong>
                <div className="small muted">{tariff.currency_code}</div>
              </div>,
              tariff.regulatory_body,
              tariff.tariff_structure,
              vehicle?.name ?? 'All goods vehicles',
              <span className="small" key="e">
                {formatDate(tariff.effective_from)}
                <br />
                {tariff.effective_to ? formatDate(tariff.effective_to) : 'Open-ended'}
              </span>,
              <StatusBadge key="s" value={tariff.is_active ? 'active' : 'disabled'} />,
            ];
          })}
          empty="No regulated tariffs found."
        />
      </div>
    </>
  );
}
