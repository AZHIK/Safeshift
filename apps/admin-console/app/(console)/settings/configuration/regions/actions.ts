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
import { regions } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the regions rows. */
export async function listRegions(filters: ListFilters) {
  return listConfigurationRecords(regions, filters);
}

/** Creates one regions. */
export async function createRegion(values: ConfigFieldValues) {
  return createConfigurationRecord(regions, values);
}

/** Updates one regions. */
export async function updateRegion(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(regions, id, values);
}

/** Deactivates one regions. */
export async function deactivateRegion(id: string, reason: string) {
  return deactivateConfigurationRecord(regions, id, reason);
}

/** Removes one regions. */
export async function deleteRegion(id: string) {
  return deleteConfigurationRecord(regions, id);
}

/** Reads the audit trail of one regions. */
export async function getRegionAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(regions, id, query);
}

/** Counts what still references one regions. */
export async function getRegionReferences(id: string) {
  return configurationReferences(regions, id);
}
