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
import { verificationChecklists } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the checklist template rows. */
export async function listVerificationChecklists(filters: ListFilters) {
  return listConfigurationRecords(verificationChecklists, filters);
}

/** Creates one checklist template. */
export async function createVerificationChecklist(values: ConfigFieldValues) {
  return createConfigurationRecord(verificationChecklists, values);
}

/** Updates one checklist template. */
export async function updateVerificationChecklist(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(verificationChecklists, id, values);
}

/** Deactivates one checklist template. */
export async function deactivateVerificationChecklist(id: string, reason: string) {
  return deactivateConfigurationRecord(verificationChecklists, id, reason);
}

/** Removes one checklist template. */
export async function deleteVerificationChecklist(id: string) {
  return deleteConfigurationRecord(verificationChecklists, id);
}

/** Reads the audit trail of one checklist template. */
export async function getVerificationChecklistAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(verificationChecklists, id, query);
}

/** Counts what still references one checklist template. */
export async function getVerificationChecklistReferences(id: string) {
  return configurationReferences(verificationChecklists, id);
}
