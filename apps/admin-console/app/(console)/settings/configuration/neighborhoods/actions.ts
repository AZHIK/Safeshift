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
import { neighborhoods } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the neighborhoods rows. */
export async function listNeighborhoods(filters: ListFilters) {
  return listConfigurationRecords(neighborhoods, filters);
}

/** Creates one neighborhoods. */
export async function createNeighborhood(values: ConfigFieldValues) {
  return createConfigurationRecord(neighborhoods, values);
}

/** Updates one neighborhoods. */
export async function updateNeighborhood(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(neighborhoods, id, values);
}

/** Deactivates one neighborhoods. */
export async function deactivateNeighborhood(id: string, reason: string) {
  return deactivateConfigurationRecord(neighborhoods, id, reason);
}

/** Removes one neighborhoods. */
export async function deleteNeighborhood(id: string) {
  return deleteConfigurationRecord(neighborhoods, id);
}

/** Reads the audit trail of one neighborhoods. */
export async function getNeighborhoodAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(neighborhoods, id, query);
}

/** Counts what still references one neighborhoods. */
export async function getNeighborhoodReferences(id: string) {
  return configurationReferences(neighborhoods, id);
}
