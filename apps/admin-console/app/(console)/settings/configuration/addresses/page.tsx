import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { addresses } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createAddress,
  deactivateAddress,
  deleteAddress,
  getAddressAuditHistory,
  getAddressReferences,
  listAddresses,
  updateAddress,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function AddressesPage() {
  await requireConfigurationPermission('manage_geography');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, addresses),
    listAddresses(filters),
  ]);

  return (
    <>
      <PageHeader title={addresses.pluralTitle} description={addresses.description} />
      <ConfigurationClient
        actions={{
          list: listAddresses,
          create: createAddress,
          update: updateAddress,
          deactivate: deactivateAddress,
          remove: deleteAddress,
          audit: getAddressAuditHistory,
          references: getAddressReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(addresses)}
      />
    </>
  );
}
