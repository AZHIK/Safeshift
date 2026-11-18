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
import { supportCategories } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the support category rows. */
export async function listSupportCategories(filters: ListFilters) {
  return listConfigurationRecords(supportCategories, filters);
}

/** Creates one support category. */
export async function createSupportCategory(values: ConfigFieldValues) {
  return createConfigurationRecord(supportCategories, values);
}

/** Updates one support category. */
export async function updateSupportCategory(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(supportCategories, id, values);
}

/** Deactivates one support category. */
export async function deactivateSupportCategory(id: string, reason: string) {
  return deactivateConfigurationRecord(supportCategories, id, reason);
}

/** Removes one support category. */
export async function deleteSupportCategory(id: string) {
  return deleteConfigurationRecord(supportCategories, id);
}

/** Reads the audit trail of one support category. */
export async function getSupportCategoryAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(supportCategories, id, query);
}

/** Counts what still references one support category. */
export async function getSupportCategoryReferences(id: string) {
  return configurationReferences(supportCategories, id);
}
