import Link from 'next/link';
import { notFound } from 'next/navigation';

import { toggleVehicleTypeAction, updateVehicleTypeAction } from '@/app/actions/admin';
import { VehicleTypeFields } from '@/components/catalog-form';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { CATALOG_ICON_FOLDERS, loadCountries, loadIconOptions } from '@/lib/catalog';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function VehicleTypePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('catalog');
  const { id } = await params;
  const query = await searchParams;
  const supabase = await createClient();

  const { data: type, error } = await supabase
    .from('vehicle_types')
    .select(
      'id, code, name, description, icon_url, country_id, capacity_kg_min, capacity_kg_max, capacity_m3_min, capacity_m3_max, number_of_wheels, requires_special_licence, display_order, is_active',
    )
    .eq('id', id)
    .maybeSingle();

  if (error) {
    return (
      <>
        <PageHeader title="Vehicle category" description="This category could not be loaded." />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!type) notFound();

  const [countries, iconOptions] = await Promise.all([
    loadCountries(supabase),
    loadIconOptions(supabase, CATALOG_ICON_FOLDERS.vehicle_types),
  ]);

  return (
    <>
      <PageHeader
        title={type.name as string}
        description={`Vehicle category ${type.code as string}. Changes apply to the apps as soon as you save.`}
        actions={
          <>
            <StatusBadge value={type.is_active ? 'active' : 'disabled'} />
            <Link className="btn" href="/catalog">
              Back to catalogue
            </Link>
          </>
        }
      />
      <Notice searchParams={query} />
      <div className="split">
        <div className="card card-pad">
          <h2 className="card-title">Details</h2>
          <p className="card-sub">
            The name, capacity and icon are what the customer sees. The code is what the pricing
            rules and the apps key on.
          </p>
          <form action={updateVehicleTypeAction} className="form" style={{ marginTop: 14 }}>
            <VehicleTypeFields
              defaults={{
                id: type.id as string,
                code: type.code as string,
                name: type.name as string,
                description: (type.description as string | null) ?? '',
                iconUrl: (type.icon_url as string | null) ?? '',
                countryId: (type.country_id as string | null) ?? '',
                capacityKgMin: type.capacity_kg_min as number | null,
                capacityKgMax: type.capacity_kg_max as number | null,
                capacityM3Min: type.capacity_m3_min as number | null,
                capacityM3Max: type.capacity_m3_max as number | null,
                numberOfWheels: type.number_of_wheels as number | null,
                requiresSpecialLicence: type.requires_special_licence === true,
                displayOrder: type.display_order as number | null,
              }}
              countries={countries}
              iconOptions={iconOptions}
            />
            <div className="inline">
              <button className="btn btn-primary" type="submit">
                Save changes
              </button>
            </div>
          </form>
        </div>
        <div className="card card-pad">
          <h2 className="card-title">Visibility</h2>
          <p className="card-sub">
            A deactivated category disappears from the booking flow and from the driver onboarding
            form. Existing vehicles and quotes keep pointing at it.
          </p>
          <form action={toggleVehicleTypeAction} style={{ marginTop: 14 }}>
            <input type="hidden" name="id" value={type.id} />
            <input type="hidden" name="active" value={type.is_active ? 'false' : 'true'} />
            <button className="btn" type="submit">
              {type.is_active ? 'Deactivate category' : 'Activate category'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
