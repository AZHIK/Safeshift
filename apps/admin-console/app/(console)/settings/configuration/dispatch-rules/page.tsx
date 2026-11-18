import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import {
  DispatchResolutionPreview,
  type DispatchRuleRow,
  type DispatchScopeOption,
} from '@/components/configuration/specials/dispatch-resolution-preview';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { dispatchRules } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createDispatchRule,
  deactivateDispatchRule,
  deleteDispatchRule,
  getDispatchRuleAuditHistory,
  getDispatchRuleReferences,
  listDispatchRules,
  updateDispatchRule,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function DispatchRulesPage() {
  await requireConfigurationPermission('manage_dispatch');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 50 };
  const [options, initial, ruleResult] = await Promise.all([
    loadOptionsFor(supabase, dispatchRules),
    listDispatchRules(filters),
    supabase
      .from('dispatch_rules')
      .select(
        'id, country_id, city_id, vehicle_type_id, max_search_radius_km, offer_timeout_seconds, max_concurrent_offers, reassign_after_seconds, minimum_acceptance_rate, min_driver_rating, is_active, countries(name), cities(name), vehicle_types(name)',
      )
      .order('country_id'),
  ]);

  const dispatchRows = ((ruleResult.data ?? []) as unknown as Record<string, unknown>[]).map(
    (rule) => {
      const country = rule.countries as { name?: string } | null;
      const city = rule.cities as { name?: string } | null;
      const vehicleType = rule.vehicle_types as { name?: string } | null;
      return {
        ...rule,
        country_name: country?.name ?? null,
        city_name: city?.name ?? null,
        vehicle_type_name: vehicleType?.name ?? null,
      } as unknown as DispatchRuleRow;
    },
  );

  const countries: DispatchScopeOption[] = (options.countries ?? []).map((country) => ({
    value: country.value,
    label: country.label,
  }));
  const cities: DispatchScopeOption[] = (options.cities ?? []).map((city) => ({
    value: city.value,
    label: city.label,
  }));
  const vehicleTypes: DispatchScopeOption[] = (options.vehicle_types ?? []).map((vehicleType) => ({
    value: vehicleType.value,
    label: vehicleType.label,
  }));

  return (
    <>
      <PageHeader title={dispatchRules.pluralTitle} description={dispatchRules.description} />
      <ConfigurationClient
        actions={{
          list: listDispatchRules,
          create: createDispatchRule,
          update: updateDispatchRule,
          deactivate: deactivateDispatchRule,
          remove: deleteDispatchRule,
          audit: getDispatchRuleAuditHistory,
          references: getDispatchRuleReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        sidePanel={
          <DispatchResolutionPreview
            cities={cities}
            countries={countries}
            rules={dispatchRows}
            vehicleTypes={vehicleTypes}
          />
        }
        view={toView(dispatchRules)}
      />
    </>
  );
}
