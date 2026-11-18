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
import { featureFlags } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the feature flag rows. */
export async function listFeatureFlags(filters: ListFilters) {
  return listConfigurationRecords(featureFlags, filters);
}

/** Creates one feature flag. */
export async function createFeatureFlag(values: ConfigFieldValues) {
  return createConfigurationRecord(featureFlags, values);
}

/** Updates one feature flag. */
export async function updateFeatureFlag(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(featureFlags, id, values);
}

/** Deactivates one feature flag. */
export async function deactivateFeatureFlag(id: string, reason: string) {
  return deactivateConfigurationRecord(featureFlags, id, reason);
}

/** Removes one feature flag. */
export async function deleteFeatureFlag(id: string) {
  return deleteConfigurationRecord(featureFlags, id);
}

/** Reads the audit trail of one feature flag. */
export async function getFeatureFlagAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(featureFlags, id, query);
}

/** Counts what still references one feature flag. */
export async function getFeatureFlagReferences(id: string) {
  return configurationReferences(featureFlags, id);
}
