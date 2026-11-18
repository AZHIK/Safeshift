import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { countryConfigurations } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCountryConfiguration,
  deactivateCountryConfiguration,
  deleteCountryConfiguration,
  getCountryConfigurationAuditHistory,
  getCountryConfigurationReferences,
  listCountryConfigurations,
  updateCountryConfiguration,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CountryConfigurationsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireConfigurationPermission('manage_countries');

  const params = await searchParams;
  // The Countries page links here with the country it belongs to, so the
  // operator lands on that country's settings rather than the whole list.
  const country = typeof params.country === 'string' ? params.country : 'all';

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25, country };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, countryConfigurations),
    listCountryConfigurations(filters),
  ]);

  return (
    <>
      <PageHeader
        title={countryConfigurations.pluralTitle}
        description={countryConfigurations.description}
      />
      <ConfigurationClient
        actions={{
          list: listCountryConfigurations,
          create: createCountryConfiguration,
          update: updateCountryConfiguration,
          deactivate: deactivateCountryConfiguration,
          remove: deleteCountryConfiguration,
          audit: getCountryConfigurationAuditHistory,
          references: getCountryConfigurationReferences,
        }}
        countries={options.countries ?? []}
        initialCountry={country}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(countryConfigurations)}
      />
    </>
  );
}
