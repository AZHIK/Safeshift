import Link from 'next/link';
import { notFound } from 'next/navigation';

import { toggleCargoTypeAction, updateCargoTypeAction } from '@/app/actions/admin';
import { CargoTypeFields } from '@/components/catalog-form';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import {
  CATALOG_ICON_FOLDERS,
  loadCargoCategories,
  loadCountries,
  loadIconOptions,
  loadVehicleTypeCodes,
} from '@/lib/catalog';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function CargoTypePage({
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
    .from('cargo_types')
    .select(
      'id, code, name, description, icon_url, country_id, category_id, requires_special_handling, requires_declared_value, requires_insurance, allowed_vehicle_type_codes, prohibited_vehicle_type_codes, max_value_tzs, display_order, is_active',
    )
    .eq('id', id)
    .maybeSingle();

  if (error) {
    return (
      <>
        <PageHeader title="Cargo type" description="This cargo type could not be loaded." />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!type) notFound();

  const [countries, categories, iconOptions, vehicleTypeCodes] = await Promise.all([
    loadCountries(supabase),
    loadCargoCategories(supabase),
    loadIconOptions(supabase, CATALOG_ICON_FOLDERS.cargo_types),
    loadVehicleTypeCodes(supabase),
  ]);

  const allowed = (type.allowed_vehicle_type_codes as string[] | null) ?? [];
  const prohibited = (type.prohibited_vehicle_type_codes as string[] | null) ?? [];

  return (
    <>
      <PageHeader
        title={type.name as string}
        description={`Cargo type ${type.code as string}. Changes apply to the apps as soon as you save.`}
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
            The name and icon are what the customer sees. The allow and prohibit lists decide which
            vehicle categories may carry this cargo.
          </p>
          <form action={updateCargoTypeAction} className="form" style={{ marginTop: 14 }}>
            <CargoTypeFields
              defaults={{
                id: type.id as string,
                code: type.code as string,
                name: type.name as string,
                description: (type.description as string | null) ?? '',
                iconUrl: (type.icon_url as string | null) ?? '',
                countryId: (type.country_id as string | null) ?? '',
                categoryId: (type.category_id as string | null) ?? '',
                requiresSpecialHandling: type.requires_special_handling === true,
                requiresDeclaredValue: type.requires_declared_value === true,
                requiresInsurance: type.requires_insurance === true,
                maxValueTzs: type.max_value_tzs as number | null,
                displayOrder: type.display_order as number | null,
                allowedVehicleTypeCodes: allowed,
                prohibitedVehicleTypeCodes: prohibited,
              }}
              countries={countries}
              categories={categories}
              iconOptions={iconOptions}
              vehicleTypeCodes={vehicleTypeCodes}
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
            A deactivated cargo type disappears from the booking flow. Quotes that already reference
            it keep working.
          </p>
          <form action={toggleCargoTypeAction} style={{ marginTop: 14 }}>
            <input type="hidden" name="id" value={type.id} />
            <input type="hidden" name="active" value={type.is_active ? 'false' : 'true'} />
            <button className="btn" type="submit">
              {type.is_active ? 'Deactivate cargo type' : 'Activate cargo type'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
