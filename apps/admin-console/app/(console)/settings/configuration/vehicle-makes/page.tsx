import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { vehicleMakes } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createVehicleMake,
  deactivateVehicleMake,
  deleteVehicleMake,
  getVehicleMakeAuditHistory,
  getVehicleMakeReferences,
  listVehicleMakes,
  updateVehicleMake,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function VehicleMakesPage() {
  await requireConfigurationPermission('manage_vehicle_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, vehicleMakes),
    listVehicleMakes(filters),
  ]);

  return (
    <>
      <PageHeader title={vehicleMakes.pluralTitle} description={vehicleMakes.description} />
      <ConfigurationClient
        actions={{
          list: listVehicleMakes,
          create: createVehicleMake,
          update: updateVehicleMake,
          deactivate: deactivateVehicleMake,
          remove: deleteVehicleMake,
          audit: getVehicleMakeAuditHistory,
          references: getVehicleMakeReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(vehicleMakes)}
      />
    </>
  );
}
