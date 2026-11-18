import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cargoTypes } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCargoType,
  deactivateCargoType,
  deleteCargoType,
  getCargoTypeAuditHistory,
  getCargoTypeReferences,
  listCargoTypes,
  updateCargoType,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CargoTypesPage() {
  await requireConfigurationPermission('manage_cargo_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, cargoTypes),
    listCargoTypes(filters),
  ]);

  return (
    <>
      <PageHeader title={cargoTypes.pluralTitle} description={cargoTypes.description} />
      <ConfigurationClient
        actions={{
          list: listCargoTypes,
          create: createCargoType,
          update: updateCargoType,
          deactivate: deactivateCargoType,
          remove: deleteCargoType,
          audit: getCargoTypeAuditHistory,
          references: getCargoTypeReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(cargoTypes)}
      />
    </>
  );
}
