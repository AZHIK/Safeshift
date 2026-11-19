import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { regions } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createRegion,
  deactivateRegion,
  deleteRegion,
  getRegionAuditHistory,
  getRegionReferences,
  listRegions,
  updateRegion,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function RegionsPage() {
  await requireConfigurationPermission('manage_geography');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, regions),
    listRegions(filters),
  ]);

  return (
    <>
      <PageHeader title={regions.pluralTitle} description={regions.description} />
      <ConfigurationClient
        actions={{
          list: listRegions,
          create: createRegion,
          update: updateRegion,
          deactivate: deactivateRegion,
          remove: deleteRegion,
          audit: getRegionAuditHistory,
          references: getRegionReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(regions)}
      />
    </>
  );
}
