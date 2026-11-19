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
import { addresses } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the addresses rows. */
export async function listAddresses(filters: ListFilters) {
  return listConfigurationRecords(addresses, filters);
}

/** Creates one addresses. */
export async function createAddress(values: ConfigFieldValues) {
  return createConfigurationRecord(addresses, values);
}

/** Updates one addresses. */
export async function updateAddress(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(addresses, id, values);
}

/** Deactivates one addresses. */
export async function deactivateAddress(id: string, reason: string) {
  return deactivateConfigurationRecord(addresses, id, reason);
}

/** Removes one addresses. */
export async function deleteAddress(id: string) {
  return deleteConfigurationRecord(addresses, id);
}

/** Reads the audit trail of one addresses. */
export async function getAddressAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(addresses, id, query);
}

/** Counts what still references one addresses. */
export async function getAddressReferences(id: string) {
  return configurationReferences(addresses, id);
}
