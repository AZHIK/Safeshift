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
import { localizationStrings } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the localization string rows. */
export async function listLocalizationStrings(filters: ListFilters) {
  return listConfigurationRecords(localizationStrings, filters);
}

/** Creates one localization string. */
export async function createLocalizationString(values: ConfigFieldValues) {
  return createConfigurationRecord(localizationStrings, values);
}

/** Updates one localization string. */
export async function updateLocalizationString(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(localizationStrings, id, values);
}

/** Deactivates one localization string. */
export async function deactivateLocalizationString(id: string, reason: string) {
  return deactivateConfigurationRecord(localizationStrings, id, reason);
}

/** Removes one localization string. */
export async function deleteLocalizationString(id: string) {
  return deleteConfigurationRecord(localizationStrings, id);
}

/** Reads the audit trail of one localization string. */
export async function getLocalizationStringAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(localizationStrings, id, query);
}

/** Counts what still references one localization string. */
export async function getLocalizationStringReferences(id: string) {
  return configurationReferences(localizationStrings, id);
}
