import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { countries } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCountry,
  deactivateCountry,
  deleteCountry,
  getCountryAuditHistory,
  getCountryReferences,
  listCountries,
  updateCountry,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CountriesPage() {
  await requireConfigurationPermission('manage_countries');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, countries),
    listCountries(filters),
  ]);

  return (
    <>
      <PageHeader title={countries.pluralTitle} description={countries.description} />
      <ConfigurationClient
        actions={{
          list: listCountries,
          create: createCountry,
          update: updateCountry,
          deactivate: deactivateCountry,
          remove: deleteCountry,
          audit: getCountryAuditHistory,
          references: getCountryReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(countries)}
      />
    </>
  );
}
