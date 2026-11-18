import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { ratingCategories } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createRatingCategory,
  deactivateRatingCategory,
  deleteRatingCategory,
  getRatingCategoryAuditHistory,
  getRatingCategoryReferences,
  listRatingCategories,
  updateRatingCategory,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function RatingCategoriesPage() {
  await requireConfigurationPermission('manage_ratings');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, ratingCategories),
    listRatingCategories(filters),
  ]);

  return (
    <>
      <PageHeader title={ratingCategories.pluralTitle} description={ratingCategories.description} />
      <ConfigurationClient
        actions={{
          list: listRatingCategories,
          create: createRatingCategory,
          update: updateRatingCategory,
          deactivate: deactivateRatingCategory,
          remove: deleteRatingCategory,
          audit: getRatingCategoryAuditHistory,
          references: getRatingCategoryReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(ratingCategories)}
      />
    </>
  );
}
