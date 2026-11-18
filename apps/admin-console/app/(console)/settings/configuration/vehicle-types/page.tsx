import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { VehicleTypePricingPanel } from '@/components/configuration/specials/vehicle-type-pricing-panel';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { vehicleTypes } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createVehicleType,
  deactivateVehicleType,
  deleteVehicleType,
  getVehicleTypeAuditHistory,
  getVehicleTypeReferences,
  listVehicleTypes,
  updateVehicleType,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function VehicleTypesPage() {
  await requireConfigurationPermission('manage_vehicle_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, vehicleTypes),
    listVehicleTypes(filters),
  ]);

  return (
    <>
      <PageHeader title={vehicleTypes.pluralTitle} description={vehicleTypes.description} />
      <ConfigurationClient
        actions={{
          list: listVehicleTypes,
          create: createVehicleType,
          update: updateVehicleType,
          deactivate: deactivateVehicleType,
          remove: deleteVehicleType,
          audit: getVehicleTypeAuditHistory,
          references: getVehicleTypeReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        sidePanel={<VehicleTypePricingPanel />}
        view={toView(vehicleTypes)}
      />
    </>
  );
}
