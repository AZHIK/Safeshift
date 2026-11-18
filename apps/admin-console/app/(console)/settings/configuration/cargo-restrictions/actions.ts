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
import { cargoRestrictions } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the cargo restriction rows. */
export async function listCargoRestrictions(filters: ListFilters) {
  return listConfigurationRecords(cargoRestrictions, filters);
}

/** Creates one cargo restriction. */
export async function createCargoRestriction(values: ConfigFieldValues) {
  return createConfigurationRecord(cargoRestrictions, values);
}

/** Updates one cargo restriction. */
export async function updateCargoRestriction(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cargoRestrictions, id, values);
}

/** Deactivates one cargo restriction. */
export async function deactivateCargoRestriction(id: string, reason: string) {
  return deactivateConfigurationRecord(cargoRestrictions, id, reason);
}

/** Removes one cargo restriction. */
export async function deleteCargoRestriction(id: string) {
  return deleteConfigurationRecord(cargoRestrictions, id);
}

/** Reads the audit trail of one cargo restriction. */
export async function getCargoRestrictionAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cargoRestrictions, id, query);
}

/** Counts what still references one cargo restriction. */
export async function getCargoRestrictionReferences(id: string) {
  return configurationReferences(cargoRestrictions, id);
}
