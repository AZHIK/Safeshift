/**
 * The shared implementation behind the twenty-one pages' server actions.
 *
 * Each page's `actions.ts` exports named actions (`createVehicleType`,
 * `updateVehicleType`, ...) that call into these helpers. Keeping the
 * implementation here means the permission check, the validation, the audit
 * trail and the cache invalidation cannot drift apart between pages.
 */

import { revalidatePath } from 'next/cache';

import { CONFIGURATION_SLUG_BY_TABLE } from './resources';
import type { ReferenceCount } from '@/components/configuration/deactivate-confirm-dialog';
import type { AuditEntry, AuditQuery } from '@/components/configuration/audit-history-button';

import {
  createRecord,
  deactivateRecord,
  deleteRecord,
  getAuditHistory,
  getReferencingCounts,
  listRecords,
  updateRecord,
  withAdminPermission,
} from './server';
import type { ConfigFieldValues, ConfigResource, ListFilters } from './types';

/** The page path of a configuration table. */
export function configPath(resource: ConfigResource): string {
  const slug = CONFIGURATION_SLUG_BY_TABLE[resource.table] ?? resource.table.replace(/_/g, '-');
  return `/settings/configuration/${slug}`;
}

/** Lists the rows of one configuration table. */
export async function listConfigurationRecords(resource: ConfigResource, filters: ListFilters) {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    listRecords(resource, filters, client),
  );

  if (!result.ok) {
    return {
      success: false,
      error: result.error,
      rows: [],
      total: 0,
      page: filters.page ?? 1,
      pageSize: filters.pageSize ?? 25,
    };
  }

  return { success: true, ...result.value };
}

/** Creates one configuration row. */
export async function createConfigurationRecord(
  resource: ConfigResource,
  values: ConfigFieldValues,
) {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    createRecord(resource, values, client),
  );

  if (!result.ok) {
    return { success: false, error: result.error };
  }

  const outcome = result.value;
  if (!outcome.success) {
    return {
      success: false,
      error: outcome.error,
      fieldErrors: outcome.fieldErrors,
    };
  }

  revalidatePath(configPath(resource));
  return { success: true, data: outcome.data };
}

/** Updates one configuration row. */
export async function updateConfigurationRecord(
  resource: ConfigResource,
  id: string,
  values: ConfigFieldValues,
) {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    updateRecord(resource, id, values, client),
  );

  if (!result.ok) {
    return { success: false, error: result.error };
  }

  const outcome = result.value;
  if (!outcome.success) {
    return {
      success: false,
      error: outcome.error,
      fieldErrors: outcome.fieldErrors,
    };
  }

  revalidatePath(configPath(resource));
  return { success: true, data: outcome.data };
}

/** Deactivates one configuration row. */
export async function deactivateConfigurationRecord(
  resource: ConfigResource,
  id: string,
  reason: string,
) {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    deactivateRecord(resource, id, reason, client),
  );

  if (!result.ok) {
    return { success: false, error: result.error };
  }

  const outcome = result.value;
  if (!outcome.success) {
    return { success: false, error: outcome.error };
  }

  revalidatePath(configPath(resource));
  return { success: true, data: outcome.data };
}

/** Removes one configuration row. */
export async function deleteConfigurationRecord(resource: ConfigResource, id: string) {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    deleteRecord(resource, id, client),
  );

  if (!result.ok) {
    return { success: false, error: result.error };
  }

  const outcome = result.value;
  if (!outcome.success) {
    return { success: false, error: outcome.error };
  }

  revalidatePath(configPath(resource));
  return { success: true, data: outcome.data };
}

/** Reads the audit trail of one configuration row. */
export async function configurationAuditHistory(
  resource: ConfigResource,
  id: string,
  query: AuditQuery = {},
): Promise<AuditEntry[]> {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    getAuditHistory(resource, id, query, client),
  );

  if (!result.ok) return [];
  return result.value;
}

/** Counts the live rows that reference one configuration row. */
export async function configurationReferences(
  resource: ConfigResource,
  id: string,
): Promise<ReferenceCount[]> {
  const result = await withAdminPermission(resource.permission, async ({ client }) =>
    getReferencingCounts(resource, id, client),
  );

  if (!result.ok) return [];

  return (resource.references ?? []).map((reference) => ({
    label: reference.label,
    count: result.value[reference.key] ?? 0,
    blocking: reference.blocking !== false,
  }));
}
