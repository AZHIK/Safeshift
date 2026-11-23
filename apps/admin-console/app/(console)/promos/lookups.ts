import { createClient } from '@/lib/supabase/server';

import type { PromoLookups } from './promo-form';

type Named = { id: string; name: string };

/** Options for the promo form: countries, cities, vehicle and cargo types, zones. */
export async function loadPromoLookups(): Promise<PromoLookups> {
  const supabase = await createClient();
  const [countries, cities, vehicles, cargo, zones] = await Promise.all([
    supabase.from('countries').select('id, name').eq('is_active', true).order('name'),
    supabase.from('cities').select('id, name, country_id').eq('is_active', true).order('name'),
    supabase.from('vehicle_types').select('id, name').eq('is_active', true).order('display_order'),
    supabase.from('cargo_types').select('id, name').eq('is_active', true).order('display_order'),
    supabase.from('service_zones').select('id, name, cities(name)').eq('is_active', true).order('name'),
  ]);
  const options = (rows: unknown[] | null) =>
    ((rows ?? []) as Named[]).map((r) => ({ id: String(r.id), name: String(r.name) }));
  return {
    countries: options(countries.data),
    cities: ((cities.data ?? []) as (Named & { country_id: string })[]).map((c) => ({
      id: String(c.id),
      name: String(c.name),
      country_id: String(c.country_id),
    })),
    vehicleTypes: options(vehicles.data),
    cargoTypes: options(cargo.data),
    zones: ((zones.data ?? []) as unknown as (Named & { cities: { name?: string } | null })[]).map((z) => ({
      id: String(z.id),
      name: z.cities?.name ? `${z.name} (${z.cities.name})` : String(z.name),
    })),
  };
}
