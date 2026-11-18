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
import { ratingCategories } from '@/lib/configuration/resources';
import type { ConfigFieldValues, ListFilters } from '@/lib/configuration/types';

/** Lists the rating category rows. */
export async function listRatingCategories(filters: ListFilters) {
  return listConfigurationRecords(ratingCategories, filters);
}

/** Creates one rating category. */
export async function createRatingCategory(values: ConfigFieldValues) {
  return createConfigurationRecord(ratingCategories, values);
}

/** Updates one rating category. */
export async function updateRatingCategory(id: string, values: ConfigFieldValues) {
  return updateConfigurationRecord(ratingCategories, id, values);
}

/** Deactivates one rating category. */
export async function deactivateRatingCategory(id: string, reason: string) {
  return deactivateConfigurationRecord(ratingCategories, id, reason);
}

/** Removes one rating category. */
export async function deleteRatingCategory(id: string) {
  return deleteConfigurationRecord(ratingCategories, id);
}

/** Reads the audit trail of one rating category. */
export async function getRatingCategoryAuditHistory(id: string, query: AuditQuery = {}) {
  return configurationAuditHistory(ratingCategories, id, query);
}

/** Counts what still references one rating category. */
export async function getRatingCategoryReferences(id: string) {
  return configurationReferences(ratingCategories, id);
}
