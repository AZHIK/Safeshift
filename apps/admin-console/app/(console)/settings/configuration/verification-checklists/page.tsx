import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { verificationChecklists } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createVerificationChecklist,
  deactivateVerificationChecklist,
  deleteVerificationChecklist,
  getVerificationChecklistAuditHistory,
  getVerificationChecklistReferences,
  listVerificationChecklists,
  updateVerificationChecklist,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function VerificationChecklistsPage() {
  await requireConfigurationPermission('manage_document_types');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, verificationChecklists),
    listVerificationChecklists(filters),
  ]);

  return (
    <>
      <PageHeader
        title={verificationChecklists.pluralTitle}
        description={verificationChecklists.description}
      />
      <ConfigurationClient
        actions={{
          list: listVerificationChecklists,
          create: createVerificationChecklist,
          update: updateVerificationChecklist,
          deactivate: deactivateVerificationChecklist,
          remove: deleteVerificationChecklist,
          audit: getVerificationChecklistAuditHistory,
          references: getVerificationChecklistReferences,
        }}
        countries={options.countries ?? []}
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        view={toView(verificationChecklists)}
      />
    </>
  );
}
