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
import { vehicleMakes } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the vehicle make rows. */
export async function listVehicleMakes(filters: ListFilters) {
  return listConfigurationRecords(vehicleMakes, filters);
}

/** Creates one vehicle make. */
export async function createVehicleMake(values: ConfigFieldValues) {
  return createConfigurationRecord(vehicleMakes, values);
}

/** Updates one vehicle make. */
export async function updateVehicleMake(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(vehicleMakes, id, values);
}

/** Deactivates one vehicle make. */
export async function deactivateVehicleMake(id: string, reason: string) {
  return deactivateConfigurationRecord(vehicleMakes, id, reason);
}

/** Removes one vehicle make. */
export async function deleteVehicleMake(id: string) {
  return deleteConfigurationRecord(vehicleMakes, id);
}

/** Reads the audit trail of one vehicle make. */
export async function getVehicleMakeAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(vehicleMakes, id, query);
}

/** Counts what still references one vehicle make. */
export async function getVehicleMakeReferences(id: string) {
  return configurationReferences(vehicleMakes, id);
}
