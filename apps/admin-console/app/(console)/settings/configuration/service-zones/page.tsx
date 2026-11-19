import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { serviceZones } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createServiceZone,
  deactivateServiceZone,
  deleteServiceZone,
  getServiceZoneAuditHistory,
  getServiceZoneReferences,
  listServiceZones,
  updateServiceZone,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function ServiceZonesPage() {
  await requireConfigurationPermission('manage_geography');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, serviceZones),
    listServiceZones(filters),
  ]);

  return (
    <>
      <PageHeader title={serviceZones.pluralTitle} description={serviceZones.description} />
      <ConfigurationClient
        actions={{
          list: listServiceZones,
          create: createServiceZone,
          update: updateServiceZone,
          deactivate: deactivateServiceZone,
          remove: deleteServiceZone,
          audit: getServiceZoneAuditHistory,
          references: getServiceZoneReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(serviceZones)}
      />
    </>
  );
}
