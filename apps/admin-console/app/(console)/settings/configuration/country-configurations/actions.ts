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
import { countryConfigurations } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the country configuration rows. */
export async function listCountryConfigurations(filters: ListFilters) {
  return listConfigurationRecords(countryConfigurations, filters);
}

/** Creates one country configuration. */
export async function createCountryConfiguration(values: ConfigFieldValues) {
  return createConfigurationRecord(countryConfigurations, values);
}

/** Updates one country configuration. */
export async function updateCountryConfiguration(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(countryConfigurations, id, values);
}

/** Deactivates one country configuration. */
export async function deactivateCountryConfiguration(id: string, reason: string) {
  return deactivateConfigurationRecord(countryConfigurations, id, reason);
}

/** Removes one country configuration. */
export async function deleteCountryConfiguration(id: string) {
  return deleteConfigurationRecord(countryConfigurations, id);
}

/** Reads the audit trail of one country configuration. */
export async function getCountryConfigurationAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(countryConfigurations, id, query);
}

/** Counts what still references one country configuration. */
export async function getCountryConfigurationReferences(id: string) {
  return configurationReferences(countryConfigurations, id);
}
