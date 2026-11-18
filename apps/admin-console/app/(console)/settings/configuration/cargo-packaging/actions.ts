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
import { cargoPackaging } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the packaging option rows. */
export async function listCargoPackaging(filters: ListFilters) {
  return listConfigurationRecords(cargoPackaging, filters);
}

/** Creates one packaging option. */
export async function createCargoPackaging(values: ConfigFieldValues) {
  return createConfigurationRecord(cargoPackaging, values);
}

/** Updates one packaging option. */
export async function updateCargoPackaging(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cargoPackaging, id, values);
}

/** Deactivates one packaging option. */
export async function deactivateCargoPackaging(id: string, reason: string) {
  return deactivateConfigurationRecord(cargoPackaging, id, reason);
}

/** Removes one packaging option. */
export async function deleteCargoPackaging(id: string) {
  return deleteConfigurationRecord(cargoPackaging, id);
}

/** Reads the audit trail of one packaging option. */
export async function getCargoPackagingAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cargoPackaging, id, query);
}

/** Counts what still references one packaging option. */
export async function getCargoPackagingReferences(id: string) {
  return configurationReferences(cargoPackaging, id);
}
