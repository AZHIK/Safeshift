import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { cargoPackaging } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createCargoPackaging,
  deactivateCargoPackaging,
  deleteCargoPackaging,
  getCargoPackagingAuditHistory,
  getCargoPackagingReferences,
  listCargoPackaging,
  updateCargoPackaging,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function CargoPackagingPage() {
  await requireConfigurationPermission('manage_cargo_catalog');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, cargoPackaging),
    listCargoPackaging(filters),
  ]);

  return (
    <>
      <PageHeader title={cargoPackaging.pluralTitle} description={cargoPackaging.description} />
      <ConfigurationClient
        actions={{
          list: listCargoPackaging,
          create: createCargoPackaging,
          update: updateCargoPackaging,
          deactivate: deactivateCargoPackaging,
          remove: deleteCargoPackaging,
          audit: getCargoPackagingAuditHistory,
          references: getCargoPackagingReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(cargoPackaging)}
      />
    </>
  );
}
