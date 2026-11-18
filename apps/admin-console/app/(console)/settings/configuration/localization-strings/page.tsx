import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { localizationStrings } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createLocalizationString,
  deactivateLocalizationString,
  deleteLocalizationString,
  getLocalizationStringAuditHistory,
  getLocalizationStringReferences,
  listLocalizationStrings,
  updateLocalizationString,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function LocalizationStringsPage() {
  await requireConfigurationPermission('manage_localization');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, localizationStrings),
    listLocalizationStrings(filters),
  ]);

  return (
    <>
      <PageHeader
        title={localizationStrings.pluralTitle}
        description={localizationStrings.description}
      />
      <ConfigurationClient
        actions={{
          list: listLocalizationStrings,
          create: createLocalizationString,
          update: updateLocalizationString,
          deactivate: deactivateLocalizationString,
          remove: deleteLocalizationString,
          audit: getLocalizationStringAuditHistory,
          references: getLocalizationStringReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(localizationStrings)}
      />
    </>
  );
}
