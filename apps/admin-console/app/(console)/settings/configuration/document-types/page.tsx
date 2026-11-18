import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { documentTypes } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createDocumentType,
  deactivateDocumentType,
  deleteDocumentType,
  getDocumentTypeAuditHistory,
  getDocumentTypeReferences,
  listDocumentTypes,
  updateDocumentType,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function DocumentTypesPage() {
  await requireConfigurationPermission('manage_document_types');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, documentTypes),
    listDocumentTypes(filters),
  ]);

  return (
    <>
      <PageHeader title={documentTypes.pluralTitle} description={documentTypes.description} />
      <ConfigurationClient
        actions={{
          list: listDocumentTypes,
          create: createDocumentType,
          update: updateDocumentType,
          deactivate: deactivateDocumentType,
          remove: deleteDocumentType,
          audit: getDocumentTypeAuditHistory,
          references: getDocumentTypeReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(documentTypes)}
      />
    </>
  );
}
