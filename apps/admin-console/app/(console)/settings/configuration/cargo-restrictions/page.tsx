import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cargoRestrictions } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCargoRestriction,
  deactivateCargoRestriction,
  deleteCargoRestriction,
  getCargoRestrictionAuditHistory,
  getCargoRestrictionReferences,
  listCargoRestrictions,
  updateCargoRestriction,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CargoRestrictionsPage() {
  await requireConfigurationPermission('manage_cargo_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, cargoRestrictions),
    listCargoRestrictions(filters),
  ]);

  return (
    <>
      <PageHeader
        title={cargoRestrictions.pluralTitle}
        description={cargoRestrictions.description}
      />
      <ConfigurationClient
        actions={{
          list: listCargoRestrictions,
          create: createCargoRestriction,
          update: updateCargoRestriction,
          deactivate: deactivateCargoRestriction,
          remove: deleteCargoRestriction,
          audit: getCargoRestrictionAuditHistory,
          references: getCargoRestrictionReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(cargoRestrictions)}
      />
    </>
  );
}
