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
import { cargoCategories } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the cargo category rows. */
export async function listCargoCategories(filters: ListFilters) {
  return listConfigurationRecords(cargoCategories, filters);
}

/** Creates one cargo category. */
export async function createCargoCategory(values: ConfigFieldValues) {
  return createConfigurationRecord(cargoCategories, values);
}

/** Updates one cargo category. */
export async function updateCargoCategory(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cargoCategories, id, values);
}

/** Deactivates one cargo category. */
export async function deactivateCargoCategory(id: string, reason: string) {
  return deactivateConfigurationRecord(cargoCategories, id, reason);
}

/** Removes one cargo category. */
export async function deleteCargoCategory(id: string) {
  return deleteConfigurationRecord(cargoCategories, id);
}

/** Reads the audit trail of one cargo category. */
export async function getCargoCategoryAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cargoCategories, id, query);
}

/** Counts what still references one cargo category. */
export async function getCargoCategoryReferences(id: string) {
  return configurationReferences(cargoCategories, id);
}
