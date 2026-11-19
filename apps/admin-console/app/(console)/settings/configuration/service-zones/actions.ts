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
import { serviceZones } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the serviceZones rows. */
export async function listServiceZones(filters: ListFilters) {
  return listConfigurationRecords(serviceZones, filters);
}

/** Creates one serviceZones. */
export async function createServiceZone(values: ConfigFieldValues) {
  return createConfigurationRecord(serviceZones, values);
}

/** Updates one serviceZones. */
export async function updateServiceZone(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(serviceZones, id, values);
}

/** Deactivates one serviceZones. */
export async function deactivateServiceZone(id: string, reason: string) {
  return deactivateConfigurationRecord(serviceZones, id, reason);
}

/** Removes one serviceZones. */
export async function deleteServiceZone(id: string) {
  return deleteConfigurationRecord(serviceZones, id);
}

/** Reads the audit trail of one serviceZones. */
export async function getServiceZoneAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(serviceZones, id, query);
}

/** Counts what still references one serviceZones. */
export async function getServiceZoneReferences(id: string) {
  return configurationReferences(serviceZones, id);
}
