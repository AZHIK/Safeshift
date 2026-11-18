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
import { cargoTypes } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the cargo type rows. */
export async function listCargoTypes(filters: ListFilters) {
  return listConfigurationRecords(cargoTypes, filters);
}

/** Creates one cargo type. */
export async function createCargoType(values: ConfigFieldValues) {
  return createConfigurationRecord(cargoTypes, values);
}

/** Updates one cargo type. */
export async function updateCargoType(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cargoTypes, id, values);
}

/** Deactivates one cargo type. */
export async function deactivateCargoType(id: string, reason: string) {
  return deactivateConfigurationRecord(cargoTypes, id, reason);
}

/** Removes one cargo type. */
export async function deleteCargoType(id: string) {
  return deleteConfigurationRecord(cargoTypes, id);
}

/** Reads the audit trail of one cargo type. */
export async function getCargoTypeAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cargoTypes, id, query);
}

/** Counts what still references one cargo type. */
export async function getCargoTypeReferences(id: string) {
  return configurationReferences(cargoTypes, id);
}
