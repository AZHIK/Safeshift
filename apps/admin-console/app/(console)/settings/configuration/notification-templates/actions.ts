'use server';

import type { AuditQuery } from '@/components/configuration/audit-history-button';
import {
  configurationAuditHistory,
  configurationReferences,
  createConfigurationRecord,
  deactivateConfigurationRecord,
  deleteConfigurationRecord,
  listConfigurationRecords,
  updateConfigurationRecord,
} from '@/lib/configuration/action-helpers';
import { notificationTemplates } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the notification template rows. */
export async function listNotificationTemplates(filters: ListFilters) {
  return listConfigurationRecords(notificationTemplates, filters);
}

/** Creates one notification template. */
export async function createNotificationTemplate(values: ConfigFieldValues) {
  return createConfigurationRecord(notificationTemplates, values);
}

/** Updates one notification template. */
export async function updateNotificationTemplate(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(notificationTemplates, id, values);
}

/** Deactivates one notification template. */
export async function deactivateNotificationTemplate(id: string, reason: string) {
  return deactivateConfigurationRecord(notificationTemplates, id, reason);
}

/** Removes one notification template. */
export async function deleteNotificationTemplate(id: string) {
  return deleteConfigurationRecord(notificationTemplates, id);
}

/** Reads the audit trail of one notification template. */
export async function getNotificationTemplateAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(notificationTemplates, id, query);
}

/** Counts what still references one notification template. */
export async function getNotificationTemplateReferences(id: string) {
  return configurationReferences(notificationTemplates, id);
}
