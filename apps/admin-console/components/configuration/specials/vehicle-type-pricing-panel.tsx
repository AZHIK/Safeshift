import { createClient } from '@/lib/supabase/server';

/**
 * The pricing coverage warning.
 *
 * A vehicle type the customer can book but the platform cannot price is a
 * booking that fails at the last step, so the panel names the types that
 * still need a pricing plan.
 */
export async function VehicleTypePricingPanel() {
  const supabase = await createClient();

  const [{ data: coverage }, { data: types }] = await Promise.all([
    supabase.rpc('admin_pricing_coverage'),
    supabase
      .from('vehicle_types')
      .select('id, code, name, is_active')
      .eq('is_active', true)
      .order('display_order'),
  ]);

  const counts = new Map<string, number>();
  for (const entry of (coverage ?? []) as {
    vehicle_type_id: string;
    pricing_plan_count: number;
  }[]) {
    counts.set(entry.vehicle_type_id, Number(entry.pricing_plan_count ?? 0));
  }

  const missing = (types ?? [])
    .map((type) => ({
      id: String(type.id),
      code: String(type.code),
      name: String(type.name),
      count: counts.get(String(type.id)) ?? 0,
    }))
    .filter((type) => type.count === 0);

  if (missing.length === 0) {
    return (
      <div className="card card-pad">
        <h3 className="card-title">Pricing coverage</h3>
        <p className="card-sub">
          Every active vehicle type has at least one pricing plan. New bookings will price
          correctly.
        </p>
      </div>
    );
  }

  return (
    <div className="card card-pad">
      <h3 className="card-title">Pricing coverage</h3>
      <p className="card-sub">
        These active vehicle types have no pricing plan. A customer can book them, but the quote
        will fail until a plan exists.
      </p>
      <div className="notice notice-info" style={{ marginTop: 10, marginBottom: 0 }}>
        {missing.length} vehicle type{missing.length === 1 ? '' : 's'} without a pricing plan.
      </div>
      <ul className="small" style={{ margin: '10px 0 0', paddingLeft: 18 }}>
        {missing.map((type) => (
          <li key={type.id}>
            <strong>{type.name}</strong> <span className="mono muted">{type.code}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
