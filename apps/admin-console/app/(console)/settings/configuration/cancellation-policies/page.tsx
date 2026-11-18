import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import {
  CancellationCalculator,
  type CancellationPolicyRow,
} from '@/components/configuration/specials/cancellation-calculator';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cancellationPolicies } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCancellationPolicy,
  deactivateCancellationPolicy,
  deleteCancellationPolicy,
  getCancellationPolicyAuditHistory,
  getCancellationPolicyReferences,
  listCancellationPolicies,
  updateCancellationPolicy,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CancellationPoliciesPage() {
  await requireConfigurationPermission('manage_cancellation_policies');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 50 };
  const [options, initial, policyResult] = await Promise.all([
    loadOptionsFor(supabase, cancellationPolicies),
    listCancellationPolicies(filters),
    supabase
      .from('cancellation_policies')
      .select(
        'id, name, applies_to_role, free_cancellation_window_minutes, fee_type, fee_value, currency_code, fee_tiers, is_active',
      )
      .order('name'),
  ]);

  const policies = (policyResult.data ?? []) as unknown as CancellationPolicyRow[];

  return (
    <>
      <PageHeader
        title={cancellationPolicies.pluralTitle}
        description={cancellationPolicies.description}
      />
      <ConfigurationClient
        actions={{
          list: listCancellationPolicies,
          create: createCancellationPolicy,
          update: updateCancellationPolicy,
          deactivate: deactivateCancellationPolicy,
          remove: deleteCancellationPolicy,
          audit: getCancellationPolicyAuditHistory,
          references: getCancellationPolicyReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        sidePanel={<CancellationCalculator policies={policies} />}
        view={toView(cancellationPolicies)}
      />
    </>
  );
}
