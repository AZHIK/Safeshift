import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { prohibitedItems } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createProhibitedItem,
  deactivateProhibitedItem,
  deleteProhibitedItem,
  getProhibitedItemAuditHistory,
  getProhibitedItemReferences,
  listProhibitedItems,
  updateProhibitedItem,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function ProhibitedItemsPage() {
  await requireConfigurationPermission('manage_prohibited_items');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, prohibitedItems),
    listProhibitedItems(filters),
  ]);

  return (
    <>
      <PageHeader title={prohibitedItems.pluralTitle} description={prohibitedItems.description} />
      <ConfigurationClient
        actions={{
          list: listProhibitedItems,
          create: createProhibitedItem,
          update: updateProhibitedItem,
          deactivate: deactivateProhibitedItem,
          remove: deleteProhibitedItem,
          audit: getProhibitedItemAuditHistory,
          references: getProhibitedItemReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(prohibitedItems)}
      />
    </>
  );
}
