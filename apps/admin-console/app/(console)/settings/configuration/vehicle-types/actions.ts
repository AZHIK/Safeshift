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
import { vehicleTypes } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the vehicle type rows. */
export async function listVehicleTypes(filters: ListFilters) {
  return listConfigurationRecords(vehicleTypes, filters);
}

/** Creates one vehicle type. */
export async function createVehicleType(values: ConfigFieldValues) {
  return createConfigurationRecord(vehicleTypes, values);
}

/** Updates one vehicle type. */
export async function updateVehicleType(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(vehicleTypes, id, values);
}

/** Deactivates one vehicle type. */
export async function deactivateVehicleType(id: string, reason: string) {
  return deactivateConfigurationRecord(vehicleTypes, id, reason);
}

/** Removes one vehicle type. */
export async function deleteVehicleType(id: string) {
  return deleteConfigurationRecord(vehicleTypes, id);
}

/** Reads the audit trail of one vehicle type. */
export async function getVehicleTypeAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(vehicleTypes, id, query);
}

/** Counts what still references one vehicle type. */
export async function getVehicleTypeReferences(id: string) {
  return configurationReferences(vehicleTypes, id);
}
