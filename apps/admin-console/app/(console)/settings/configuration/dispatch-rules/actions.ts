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
import { dispatchRules } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the dispatch rule rows. */
export async function listDispatchRules(filters: ListFilters) {
  return listConfigurationRecords(dispatchRules, filters);
}

/** Creates one dispatch rule. */
export async function createDispatchRule(values: ConfigFieldValues) {
  return createConfigurationRecord(dispatchRules, values);
}

/** Updates one dispatch rule. */
export async function updateDispatchRule(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(dispatchRules, id, values);
}

/** Deactivates one dispatch rule. */
export async function deactivateDispatchRule(id: string, reason: string) {
  return deactivateConfigurationRecord(dispatchRules, id, reason);
}

/** Removes one dispatch rule. */
export async function deleteDispatchRule(id: string) {
  return deleteConfigurationRecord(dispatchRules, id);
}

/** Reads the audit trail of one dispatch rule. */
export async function getDispatchRuleAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(dispatchRules, id, query);
}

/** Counts what still references one dispatch rule. */
export async function getDispatchRuleReferences(id: string) {
  return configurationReferences(dispatchRules, id);
}
