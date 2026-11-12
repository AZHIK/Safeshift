import Link from 'next/link';

import {
  createCargoTypeAction,
  createVehicleTypeAction,
  deleteCargoTypeAction,
  deleteVehicleTypeAction,
  toggleCargoTypeAction,
  toggleVehicleTypeAction,
} from '@/app/actions/admin';
import { CargoTypeFields, VehicleTypeFields } from '@/components/catalog-form';
import { DataTable } from '@/components/data-table';
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

export default async function CatalogPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('catalog');
  const params = await searchParams;
  const supabase = await createClient();

  const [
    { data: vehicleTypes, error: vehicleError },
    { data: cargoTypes, error: cargoError },
    countries,
    categories,
    vehicleIconOptions,
    cargoIconOptions,
    vehicleTypeCodes,
  ] = await Promise.all([
    supabase
      .from('vehicle_types')
      .select(
        'id, code, name, icon_url, country_id, capacity_kg_min, capacity_kg_max, display_order, is_active, countries(name, iso_code)',
      )
      .order('display_order')
      .limit(200),
    supabase
      .from('cargo_types')
      .select(
        'id, code, name, icon_url, country_id, category_id, display_order, is_active, cargo_categories(name), countries(name, iso_code)',
      )
      .order('display_order')
      .limit(200),
    loadCountries(supabase),
    loadCargoCategories(supabase),
    loadIconOptions(supabase, CATALOG_ICON_FOLDERS.vehicle_types),
    loadIconOptions(supabase, CATALOG_ICON_FOLDERS.cargo_types),
    loadVehicleTypeCodes(supabase),
  ]);

  const vehicleRows = (vehicleTypes ?? []).map((type) => {
    const country = type.countries as { name?: string; iso_code?: string } | null;
    return [
      <div key="c">
        <strong>{type.name}</strong>
        <div className="small muted mono">{type.code}</div>
      </div>,
      <span className="small" key="s">
        {country ? `${country.name} (${country.iso_code})` : 'Global'}
      </span>,
      <span className="small mono" key="cap">
        {type.capacity_kg_min}–{type.capacity_kg_max} kg
      </span>,
      <span className="small mono" key="i">
        {type.icon_url ?? '—'}
      </span>,
      <span className="small" key="o">
        {type.display_order}
      </span>,
      <StatusBadge key="b" value={type.is_active ? 'active' : 'disabled'} />,
      <div key="a" className="inline" style={{ gap: 6 }}>
        <Link className="btn btn-sm" href={`/catalog/vehicle-types/${type.id}`}>
          Edit
        </Link>
        <form action={toggleVehicleTypeAction}>
          <input type="hidden" name="id" value={type.id} />
          <input type="hidden" name="active" value={type.is_active ? 'false' : 'true'} />
          <button className="btn btn-sm" type="submit">
            {type.is_active ? 'Deactivate' : 'Activate'}
          </button>
        </form>
        <form action={deleteVehicleTypeAction}>
          <input type="hidden" name="id" value={type.id} />
          <button className="btn btn-sm" type="submit">
            Delete
          </button>
        </form>
      </div>,
    ];
  });

  const cargoRows = (cargoTypes ?? []).map((type) => {
    const country = type.countries as { name?: string; iso_code?: string } | null;
    const category = type.cargo_categories as { name?: string } | null;
    return [
      <div key="c">
        <strong>{type.name}</strong>
        <div className="small muted mono">{type.code}</div>
      </div>,
      <span className="small" key="s">
        {country ? `${country.name} (${country.iso_code})` : 'Global'}
      </span>,
      <span className="small" key="cat">
        {category?.name ?? '—'}
      </span>,
      <span className="small mono" key="i">
        {type.icon_url ?? '—'}
      </span>,
      <span className="small" key="o">
        {type.display_order}
      </span>,
      <StatusBadge key="b" value={type.is_active ? 'active' : 'disabled'} />,
      <div key="a" className="inline" style={{ gap: 6 }}>
        <Link className="btn btn-sm" href={`/catalog/cargo-types/${type.id}`}>
          Edit
        </Link>
        <form action={toggleCargoTypeAction}>
          <input type="hidden" name="id" value={type.id} />
          <input type="hidden" name="active" value={type.is_active ? 'false' : 'true'} />
          <button className="btn btn-sm" type="submit">
            {type.is_active ? 'Deactivate' : 'Activate'}
          </button>
        </form>
        <form action={deleteCargoTypeAction}>
          <input type="hidden" name="id" value={type.id} />
          <button className="btn btn-sm" type="submit">
            Delete
          </button>
        </form>
      </div>,
    ];
  });

  return (
    <>
      <PageHeader
        title="Catalogue"
        description="The vehicle categories and cargo types the customer and driver apps read. Nothing is hard-coded in the apps: a row that is missing here is a row the apps never show, and a deactivated row disappears from both."
      />
      <Notice searchParams={params} />
      {vehicleError ? <div className="notice notice-error">{vehicleError.message}</div> : null}
      {cargoError ? <div className="notice notice-error">{cargoError.message}</div> : null}

      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Vehicle categories</h2>
            <p className="card-sub">
              Sizes a customer can book and a driver can register. Active rows appear in the booking
              flow and in the driver onboarding form.
            </p>
          </div>
          <DataTable
            columns={['Category', 'Scope', 'Capacity', 'Icon', 'Order', 'Status', '']}
            rows={vehicleRows}
            empty="No vehicle categories yet. Add one below — until then the apps show no vehicles."
          />
          <div className="card-pad">
            <h3 className="card-title">Add a vehicle category</h3>
            <p className="card-sub">
              The code is the durable key pricing rules refer to. The icon path points at the
              catalogue bucket.
            </p>
            <form action={createVehicleTypeAction} className="form" style={{ marginTop: 12 }}>
              <VehicleTypeFields
                defaults={{}}
                countries={countries}
                iconOptions={vehicleIconOptions}
              />
              <div>
                <button className="btn btn-primary" type="submit">
                  Add vehicle category
                </button>
              </div>
            </form>
          </div>
        </div>

        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Cargo types</h2>
            <p className="card-sub">
              What a customer says they are moving. Active rows appear as the cargo chips in the
              booking flow.
            </p>
          </div>
          <DataTable
            columns={['Cargo type', 'Scope', 'Category', 'Icon', 'Order', 'Status', '']}
            rows={cargoRows}
            empty="No cargo types yet. Add one below — until then the apps show no cargo options."
          />
          <div className="card-pad">
            <h3 className="card-title">Add a cargo type</h3>
            <p className="card-sub">
              An empty allow list means the cargo may travel in any vehicle type. Prohibited codes
              are rejected by the capability check.
            </p>
            <form action={createCargoTypeAction} className="form" style={{ marginTop: 12 }}>
              <CargoTypeFields
                defaults={{}}
                countries={countries}
                categories={categories}
                iconOptions={cargoIconOptions}
                vehicleTypeCodes={vehicleTypeCodes}
              />
              <div>
                <button className="btn btn-primary" type="submit">
                  Add cargo type
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </>
  );
}
