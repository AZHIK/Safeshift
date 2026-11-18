import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cargoCategories } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCargoCategory,
  deactivateCargoCategory,
  deleteCargoCategory,
  getCargoCategoryAuditHistory,
  getCargoCategoryReferences,
  listCargoCategories,
  updateCargoCategory,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CargoCategoriesPage() {
  await requireConfigurationPermission('manage_cargo_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, cargoCategories),
    listCargoCategories(filters),
  ]);

  return (
    <>
      <PageHeader title={cargoCategories.pluralTitle} description={cargoCategories.description} />
      <ConfigurationClient
        actions={{
          list: listCargoCategories,
          create: createCargoCategory,
          update: updateCargoCategory,
          deactivate: deactivateCargoCategory,
          remove: deleteCargoCategory,
          audit: getCargoCategoryAuditHistory,
          references: getCargoCategoryReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(cargoCategories)}
      />
    </>
  );
}
