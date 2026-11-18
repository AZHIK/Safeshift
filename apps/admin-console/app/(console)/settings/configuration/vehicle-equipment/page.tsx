import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { vehicleEquipment } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createVehicleEquipment,
  deactivateVehicleEquipment,
  deleteVehicleEquipment,
  getVehicleEquipmentAuditHistory,
  getVehicleEquipmentReferences,
  listVehicleEquipment,
  updateVehicleEquipment,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function VehicleEquipmentPage() {
  await requireConfigurationPermission('manage_vehicle_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, vehicleEquipment),
    listVehicleEquipment(filters),
  ]);

  return (
    <>
      <PageHeader title={vehicleEquipment.pluralTitle} description={vehicleEquipment.description} />
      <ConfigurationClient
        actions={{
          list: listVehicleEquipment,
          create: createVehicleEquipment,
          update: updateVehicleEquipment,
          deactivate: deactivateVehicleEquipment,
          remove: deleteVehicleEquipment,
          audit: getVehicleEquipmentAuditHistory,
          references: getVehicleEquipmentReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(vehicleEquipment)}
      />
    </>
  );
}
