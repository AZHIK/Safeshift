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
import { cities } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the cities rows. */
export async function listCities(filters: ListFilters) {
  return listConfigurationRecords(cities, filters);
}

/** Creates one cities. */
export async function createCity(values: ConfigFieldValues) {
  return createConfigurationRecord(cities, values);
}

/** Updates one cities. */
export async function updateCity(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cities, id, values);
}

/** Deactivates one cities. */
export async function deactivateCity(id: string, reason: string) {
  return deactivateConfigurationRecord(cities, id, reason);
}

/** Removes one cities. */
export async function deleteCity(id: string) {
  return deleteConfigurationRecord(cities, id);
}

/** Reads the audit trail of one cities. */
export async function getCityAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cities, id, query);
}

/** Counts what still references one cities. */
export async function getCityReferences(id: string) {
  return configurationReferences(cities, id);
}
