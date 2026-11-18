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
import { prohibitedItems } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the prohibited item rows. */
export async function listProhibitedItems(filters: ListFilters) {
  return listConfigurationRecords(prohibitedItems, filters);
}

/** Creates one prohibited item. */
export async function createProhibitedItem(values: ConfigFieldValues) {
  return createConfigurationRecord(prohibitedItems, values);
}

/** Updates one prohibited item. */
export async function updateProhibitedItem(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(prohibitedItems, id, values);
}

/** Deactivates one prohibited item. */
export async function deactivateProhibitedItem(id: string, reason: string) {
  return deactivateConfigurationRecord(prohibitedItems, id, reason);
}

/** Removes one prohibited item. */
export async function deleteProhibitedItem(id: string) {
  return deleteConfigurationRecord(prohibitedItems, id);
}

/** Reads the audit trail of one prohibited item. */
export async function getProhibitedItemAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(prohibitedItems, id, query);
}

/** Counts what still references one prohibited item. */
export async function getProhibitedItemReferences(id: string) {
  return configurationReferences(prohibitedItems, id);
}
