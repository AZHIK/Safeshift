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
import { cancellationPolicies } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the cancellation policy rows. */
export async function listCancellationPolicies(filters: ListFilters) {
  return listConfigurationRecords(cancellationPolicies, filters);
}

/** Creates one cancellation policy. */
export async function createCancellationPolicy(values: ConfigFieldValues) {
  return createConfigurationRecord(cancellationPolicies, values);
}

/** Updates one cancellation policy. */
export async function updateCancellationPolicy(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(cancellationPolicies, id, values);
}

/** Deactivates one cancellation policy. */
export async function deactivateCancellationPolicy(id: string, reason: string) {
  return deactivateConfigurationRecord(cancellationPolicies, id, reason);
}

/** Removes one cancellation policy. */
export async function deleteCancellationPolicy(id: string) {
  return deleteConfigurationRecord(cancellationPolicies, id);
}

/** Reads the audit trail of one cancellation policy. */
export async function getCancellationPolicyAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(cancellationPolicies, id, query);
}

/** Counts what still references one cancellation policy. */
export async function getCancellationPolicyReferences(id: string) {
  return configurationReferences(cancellationPolicies, id);
}
