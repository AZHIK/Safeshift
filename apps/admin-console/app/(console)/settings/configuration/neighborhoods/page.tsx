import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { neighborhoods } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createNeighborhood,
  deactivateNeighborhood,
  deleteNeighborhood,
  getNeighborhoodAuditHistory,
  getNeighborhoodReferences,
  listNeighborhoods,
  updateNeighborhood,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function NeighborhoodsPage() {
  await requireConfigurationPermission('manage_geography');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, neighborhoods),
    listNeighborhoods(filters),
  ]);

  return (
    <>
      <PageHeader title={neighborhoods.pluralTitle} description={neighborhoods.description} />
      <ConfigurationClient
        actions={{
          list: listNeighborhoods,
          create: createNeighborhood,
          update: updateNeighborhood,
          deactivate: deactivateNeighborhood,
          remove: deleteNeighborhood,
          audit: getNeighborhoodAuditHistory,
          references: getNeighborhoodReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(neighborhoods)}
      />
    </>
  );
}
