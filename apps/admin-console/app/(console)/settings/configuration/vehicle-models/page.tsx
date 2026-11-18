import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { vehicleModels } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createVehicleModel,
  deactivateVehicleModel,
  deleteVehicleModel,
  getVehicleModelAuditHistory,
  getVehicleModelReferences,
  listVehicleModels,
  updateVehicleModel,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function VehicleModelsPage() {
  await requireConfigurationPermission('manage_vehicle_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, vehicleModels),
    listVehicleModels(filters),
  ]);

  return (
    <>
      <PageHeader title={vehicleModels.pluralTitle} description={vehicleModels.description} />
      <ConfigurationClient
        actions={{
          list: listVehicleModels,
          create: createVehicleModel,
          update: updateVehicleModel,
          deactivate: deactivateVehicleModel,
          remove: deleteVehicleModel,
          audit: getVehicleModelAuditHistory,
          references: getVehicleModelReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(vehicleModels)}
      />
    </>
  );
}
