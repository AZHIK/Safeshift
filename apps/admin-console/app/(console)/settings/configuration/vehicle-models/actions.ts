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
import { vehicleModels } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the vehicle model rows. */
export async function listVehicleModels(filters: ListFilters) {
  return listConfigurationRecords(vehicleModels, filters);
}

/** Creates one vehicle model. */
export async function createVehicleModel(values: ConfigFieldValues) {
  return createConfigurationRecord(vehicleModels, values);
}

/** Updates one vehicle model. */
export async function updateVehicleModel(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(vehicleModels, id, values);
}

/** Deactivates one vehicle model. */
export async function deactivateVehicleModel(id: string, reason: string) {
  return deactivateConfigurationRecord(vehicleModels, id, reason);
}

/** Removes one vehicle model. */
export async function deleteVehicleModel(id: string) {
  return deleteConfigurationRecord(vehicleModels, id);
}

/** Reads the audit trail of one vehicle model. */
export async function getVehicleModelAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(vehicleModels, id, query);
}

/** Counts what still references one vehicle model. */
export async function getVehicleModelReferences(id: string) {
  return configurationReferences(vehicleModels, id);
}
