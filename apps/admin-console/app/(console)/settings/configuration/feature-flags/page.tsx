import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { featureFlags } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createFeatureFlag,
  deactivateFeatureFlag,
  deleteFeatureFlag,
  getFeatureFlagAuditHistory,
  getFeatureFlagReferences,
  listFeatureFlags,
  updateFeatureFlag,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function FeatureFlagsPage() {
  await requireConfigurationPermission('manage_features');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, featureFlags),
    listFeatureFlags(filters),
  ]);

  return (
    <>
      <PageHeader title={featureFlags.pluralTitle} description={featureFlags.description} />
      <ConfigurationClient
        actions={{
          list: listFeatureFlags,
          create: createFeatureFlag,
          update: updateFeatureFlag,
          deactivate: deactivateFeatureFlag,
          remove: deleteFeatureFlag,
          audit: getFeatureFlagAuditHistory,
          references: getFeatureFlagReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(featureFlags)}
      />
    </>
  );
}
