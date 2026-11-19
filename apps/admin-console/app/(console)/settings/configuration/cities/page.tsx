import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cities } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCity,
  deactivateCity,
  deleteCity,
  getCityAuditHistory,
  getCityReferences,
  listCities,
  updateCity,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CitiesPage() {
  await requireConfigurationPermission('manage_geography');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, cities),
    listCities(filters),
  ]);

  return (
    <>
      <PageHeader title={cities.pluralTitle} description={cities.description} />
      <ConfigurationClient
        actions={{
          list: listCities,
          create: createCity,
          update: updateCity,
          deactivate: deactivateCity,
          remove: deleteCity,
          audit: getCityAuditHistory,
          references: getCityReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(cities)}
      />
    </>
  );
}
