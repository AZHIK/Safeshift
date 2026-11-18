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
import { vehicleEquipment } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the vehicle equipment rows. */
export async function listVehicleEquipment(filters: ListFilters) {
  return listConfigurationRecords(vehicleEquipment, filters);
}

/** Creates one vehicle equipment. */
export async function createVehicleEquipment(values: ConfigFieldValues) {
  return createConfigurationRecord(vehicleEquipment, values);
}

/** Updates one vehicle equipment. */
export async function updateVehicleEquipment(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(vehicleEquipment, id, values);
}

/** Deactivates one vehicle equipment. */
export async function deactivateVehicleEquipment(id: string, reason: string) {
  return deactivateConfigurationRecord(vehicleEquipment, id, reason);
}

/** Removes one vehicle equipment. */
export async function deleteVehicleEquipment(id: string) {
  return deleteConfigurationRecord(vehicleEquipment, id);
}

/** Reads the audit trail of one vehicle equipment. */
export async function getVehicleEquipmentAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(vehicleEquipment, id, query);
}

/** Counts what still references one vehicle equipment. */
export async function getVehicleEquipmentReferences(id: string) {
  return configurationReferences(vehicleEquipment, id);
}
