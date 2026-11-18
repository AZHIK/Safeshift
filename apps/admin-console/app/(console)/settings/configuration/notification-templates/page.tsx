import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { notificationTemplates } from '@/lib/configuration/resources';
import type { ListFilters } from '@/lib/configuration/types';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';

import {
  createNotificationTemplate,
  deactivateNotificationTemplate,
  deleteNotificationTemplate,
  getNotificationTemplateAuditHistory,
  getNotificationTemplateReferences,
  listNotificationTemplates,
  updateNotificationTemplate,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function NotificationTemplatesPage() {
  await requireConfigurationPermission('manage_notifications');

  const supabase = await createClient();
  const filters: ListFilters = { page: 1, pageSize: 25 };
  const [options, initial] = await Promise.all([
    loadOptionsFor(supabase, notificationTemplates),
    listNotificationTemplates(filters),
  ]);

  return (
    <>
      <PageHeader
        title={notificationTemplates.pluralTitle}
        description={notificationTemplates.description}
      />
      <ConfigurationClient
        actions={{
          list: listNotificationTemplates,
          create: createNotificationTemplate,
          update: updateNotificationTemplate,
          deactivate: deactivateNotificationTemplate,
          remove: deleteNotificationTemplate,
          audit: getNotificationTemplateAuditHistory,
          references: getNotificationTemplateReferences,
        }}
        countries={options.countries ?? []}
        createLabel="New template"
        initialPage={initial.page}
        initialRows={initial.rows ?? []}
        initialTotal={initial.total ?? 0}
        options={options}
        preview={{
          titleField: 'title_template',
          bodyField: 'body_template',
          variablesField: 'variables',
        }}
        view={toView(notificationTemplates)}
      />
    </>
  );
}
