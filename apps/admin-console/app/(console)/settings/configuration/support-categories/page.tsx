import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { supportCategories } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createSupportCategory,
  deactivateSupportCategory,
  deleteSupportCategory,
  getSupportCategoryAuditHistory,
  getSupportCategoryReferences,
  listSupportCategories,
  updateSupportCategory,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function SupportCategoriesPage() {
  await requireConfigurationPermission('manage_support');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, supportCategories),
    listSupportCategories(filters),
  ]);

  return (
    <>
      <PageHeader
        title={supportCategories.pluralTitle}
        description={supportCategories.description}
      />
      <ConfigurationClient
        actions={{
          list: listSupportCategories,
          create: createSupportCategory,
          update: updateSupportCategory,
          deactivate: deactivateSupportCategory,
          remove: deleteSupportCategory,
          audit: getSupportCategoryAuditHistory,
          references: getSupportCategoryReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(supportCategories)}
      />
    </>
  );
}
