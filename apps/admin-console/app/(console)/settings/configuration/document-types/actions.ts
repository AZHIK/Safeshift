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
import { documentTypes } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the document type rows. */
export async function listDocumentTypes(filters: ListFilters) {
  return listConfigurationRecords(documentTypes, filters);
}

/** Creates one document type. */
export async function createDocumentType(values: ConfigFieldValues) {
  return createConfigurationRecord(documentTypes, values);
}

/** Updates one document type. */
export async function updateDocumentType(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(documentTypes, id, values);
}

/** Deactivates one document type. */
export async function deactivateDocumentType(id: string, reason: string) {
  return deactivateConfigurationRecord(documentTypes, id, reason);
}

/** Removes one document type. */
export async function deleteDocumentType(id: string) {
  return deleteConfigurationRecord(documentTypes, id);
}

/** Reads the audit trail of one document type. */
export async function getDocumentTypeAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(documentTypes, id, query);
}

/** Counts what still references one document type. */
export async function getDocumentTypeReferences(id: string) {
  return configurationReferences(documentTypes, id);
}
