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
import { countries } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the country rows. */
export async function listCountries(filters: ListFilters) {
  return listConfigurationRecords(countries, filters);
}

/** Creates one country. */
export async function createCountry(values: ConfigFieldValues) {
  return createConfigurationRecord(countries, values);
}

/** Updates one country. */
export async function updateCountry(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(countries, id, values);
}

/** Deactivates one country. */
export async function deactivateCountry(id: string, reason: string) {
  return deactivateConfigurationRecord(countries, id, reason);
}

/** Removes one country. */
export async function deleteCountry(id: string) {
  return deleteConfigurationRecord(countries, id);
}

/** Reads the audit trail of one country. */
export async function getCountryAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(countries, id, query);
}

/** Counts what still references one country. */
export async function getCountryReferences(id: string) {
  return configurationReferences(countries, id);
}
