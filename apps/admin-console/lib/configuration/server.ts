/**
 * The configuration CRUD engine.
 *
 * Every configuration page is a thin wrapper around this module. The engine
 * owns the four things that must never vary between the twenty-one tables:
 *
 *   1. the permission check,
 *   2. the input validation,
 *   3. the audit trail (private.audit_trigger writes the row-level trail
 *      inside the same transaction as the change; public.admin_log_action
 *      writes the console's own action trail), and
 *   4. the deactivate guard that refuses to hide a row live data still uses.
 */

import type { SupabaseClient } from '@supabase/supabase-js';

import { createClient } from '@/lib/supabase/server';

import { getCallerPermissions, type CallerPermissions } from './guard';
import { buildPayload, validateValues } from './validation';
import type { ConfigFieldValues, ConfigResource, ListFilters } from './types';

/** The shape every configuration server action returns. */
export type ActionResult<T = unknown> =
  | { success: true; data: T }
  | { success: false; error: string; fieldErrors?: Record<string, string> };

export type ListResult = {
  rows: Record<string, unknown>[];
  total: number;
  page: number;
  pageSize: number;
};

export type AuditEntry = {
  entry_id: string;
  created_at: string;
  actor_id: string | null;
  actor_name: string;
  action: string;
  old_value: unknown;
  new_value: unknown;
  source: string;
};

export type AuditFilters = {
  limit?: number;
  from?: string;
  to?: string;
  actor?: string;
};

export const DEFAULT_PAGE_SIZE = 25;
export const MAX_PAGE_SIZE = 200;

/**
 * Runs a callback only for an administrator who holds the permission.
 *
 * The callback receives the caller's own Supabase client, so the write goes
 * through the row-level security policies of the table: a caller without the
 * permission is stopped by the database as well as by this check.
 */
export async function withAdminPermission<T>(
  requiredPermission: string,
  callback: (context: { client: SupabaseClient; caller: CallerPermissions }) => Promise<T>,
): Promise<{ ok: true; value: T } | { ok: false; error: string }> {
  const caller = await getCallerPermissions();
  if (!caller.permissions.has(requiredPermission)) {
    return {
      ok: false,
      error: 'You do not have permission to perform this action.',
    };
  }

  const client = await createClient();
  const { data, error: authError } = await client.auth.getUser();
  if (authError || !data.user) {
    return { ok: false, error: 'Your session has expired. Sign in again.' };
  }

  try {
    return { ok: true, value: await callback({ client, caller }) };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : 'The action could not be completed.',
    };
  }
}

/**
 * Flattens the embedded relations PostgREST returns into the flat column
 * names the table declares: `countries(name)` becomes `country_name`.
 */
function flattenRelations(row: Record<string, unknown>): void {
  for (const [key, value] of Object.entries(row)) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) continue;
    const relation = value as unknown as Record<string, unknown>;
    if (relation.name !== undefined) row[`${key}_name`] = relation.name;
    if (relation.code !== undefined) row[`${key}_code`] = relation.code;
    if (relation.iso_code !== undefined) row[`${key}_iso_code`] = relation.iso_code;
    if (relation.full_name !== undefined) row[`${key}_name`] = relation.full_name;
    if (relation.display_name !== undefined) {
      row[`${key}_display_name`] = relation.display_name;
    }
  }
}

/** Escapes the characters PostgREST treats as filter syntax. */
function escapeSearchTerm(term: string): string {
  return term.replace(/[,()%*'"\\]/g, ' ').trim();
}

/** Lists the rows of one configuration table. */
export async function listRecords(
  resource: ConfigResource,
  filters: ListFilters,
  client?: SupabaseClient,
): Promise<ListResult> {
  const supabase = client ?? (await createClient());

  const pageSize = Math.min(
    Math.max(Number(filters.pageSize ?? DEFAULT_PAGE_SIZE), 1),
    MAX_PAGE_SIZE,
  );
  const page = Math.max(Number(filters.page ?? 1), 1);

  let query = supabase.from(resource.table).select(resource.selectSpec, { count: 'exact' });

  if (resource.softDelete) {
    if (filters.status === 'active') query = query.eq('is_active', true);
    else if (filters.status === 'inactive') query = query.eq('is_active', false);
  }

  if (resource.countryScoped && filters.country && filters.country !== 'all') {
    query = query.eq('country_id', filters.country);
  }

  const search = escapeSearchTerm(String(filters.search ?? ''));
  if (search && resource.searchColumns && resource.searchColumns.length > 0) {
    const clauses = resource.searchColumns.map((column) => `${column}.ilike.*${search}*`).join(',');
    query = query.or(clauses);
  }

  for (const filter of resource.filters ?? []) {
    // A special filter is applied by the resource itself.
    if (filter.special) continue;
    const value = filters.extra?.[filter.name];
    if (!value || value === 'all') continue;
    if (filter.type === 'boolean') {
      query = query.eq(filter.name, value === 'true');
    } else {
      query = query.eq(filter.name, value);
    }
  }

  if (resource.specialListFilter) {
    const clause = await resource.specialListFilter({ client: supabase, filters });
    if (clause) query = query.or(clause.orFilter);
  }

  const sortColumn = filters.sort ?? resource.defaultSort?.column;
  if (sortColumn) {
    const ascending = filters.direction
      ? filters.direction === 'asc'
      : (resource.defaultSort?.ascending ?? true);
    query = query.order(sortColumn, { ascending, nullsFirst: false });
  }

  const from = (page - 1) * pageSize;
  query = query.range(from, from + pageSize - 1);

  const { data, error, count } = await query;
  if (error) {
    throw new Error(error.message);
  }

  const rows = (data ?? []) as unknown as unknown as Record<string, unknown>[];
  for (const row of rows) flattenRelations(row);

  if (resource.augment) {
    await resource.augment(rows, { client: supabase, filters });
  }

  return { rows, total: count ?? rows.length, page, pageSize };
}

/** Reads one row, including rows that have been deactivated. */
export async function getRecord(
  resource: ConfigResource,
  id: string,
  client?: SupabaseClient,
): Promise<Record<string, unknown> | null> {
  const supabase = client ?? (await createClient());
  const { data, error } = await supabase
    .from(resource.table)
    .select(resource.selectSpec)
    .eq('id', id)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  const row = data as unknown as Record<string, unknown>;
  flattenRelations(row);
  return row;
}

/** Checks the resource's uniqueness rules. Returns an error message or null. */
export async function assertUnique(
  resource: ConfigResource,
  payload: Record<string, unknown>,
  excludeId?: string,
  client?: SupabaseClient,
): Promise<string | null> {
  const groups = resource.uniqueColumns ?? [];
  if (groups.length === 0) return null;

  const supabase = client ?? (await createClient());

  for (const group of groups) {
    let query = supabase.from(resource.table).select('id');
    for (const column of group.columns) {
      const value = payload[column];
      if (value === null || value === undefined || value === '') {
        query = query.is(column, null);
      } else {
        query = query.eq(column, value);
      }
    }
    if (excludeId) query = query.neq('id', excludeId);

    const { data, error } = await query.limit(1);
    if (error) continue;
    if ((data ?? []).length > 0) {
      return `Another ${resource.singular} already uses this ${group.label}.`;
    }
  }

  return null;
}

/** Writes one row to the console action trail. */
export async function logAdminAction(
  client: SupabaseClient,
  action: string,
  entityType: string,
  entityId: string | null,
  oldValue: unknown,
  newValue: unknown,
  permissionUsed: string,
): Promise<void> {
  const { error } = await client.rpc('admin_log_action', {
    p_action: action,
    p_entity_type: entityType,
    p_entity_id: entityId,
    p_old_value: oldValue ?? null,
    p_new_value: newValue ?? null,
    p_permission_used: permissionUsed,
  });
  if (error) {
    throw new Error(error.message);
  }
}

/** Only the fields that actually changed, for a readable audit entry. */
function diffPayload(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Record<string, unknown> {
  const changed: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(after)) {
    const previous = before[key];
    const same =
      previous === value ||
      (previous === null && value === null) ||
      (previous === undefined && value === null) ||
      String(previous ?? '') === String(value ?? '');
    if (!same) changed[key] = value;
  }
  return changed;
}

/**
 * The value written to the audit trail.
 *
 * It is the database payload plus the form-only fields, so a note an
 * operator types is recorded even though the table has nowhere to put it.
 */
function auditPayload(
  resource: ConfigResource,
  values: ConfigFieldValues,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const audit = { ...payload };
  for (const field of resource.fields) {
    if (!field.formOnly) continue;
    const value = values[field.name];
    if (value === null || value === undefined || value === '') continue;
    audit[field.name] = value;
  }
  return audit;
}

/** Creates one configuration row. */
export async function createRecord(
  resource: ConfigResource,
  values: ConfigFieldValues,
  client: SupabaseClient,
): Promise<ActionResult<{ id: string }>> {
  const fieldErrors = validateValues(resource, values);
  if (Object.keys(fieldErrors).length > 0) {
    return {
      success: false,
      error: 'Please correct the highlighted fields.',
      fieldErrors,
    };
  }

  const payload = buildPayload(resource, values);

  const duplicate = await assertUnique(resource, payload, undefined, client);
  if (duplicate) {
    return { success: false, error: duplicate };
  }

  const { data, error } = await client.from(resource.table).insert(payload).select('id').single();

  if (error || !data) {
    return { success: false, error: error?.message ?? 'The record could not be created.' };
  }

  await logAdminAction(
    client,
    `${resource.table}.created`,
    resource.table,
    String(data.id),
    null,
    auditPayload(resource, values, payload),
    resource.permission,
  );

  return { success: true, data: { id: String(data.id) } };
}

/** Updates one configuration row. */
export async function updateRecord(
  resource: ConfigResource,
  id: string,
  values: ConfigFieldValues,
  client: SupabaseClient,
): Promise<ActionResult<{ id: string }>> {
  const fieldErrors = validateValues(resource, values);
  if (Object.keys(fieldErrors).length > 0) {
    return {
      success: false,
      error: 'Please correct the highlighted fields.',
      fieldErrors,
    };
  }

  const before = await getRecord(resource, id, client);
  if (!before) {
    return { success: false, error: 'That record no longer exists.' };
  }

  const payload = buildPayload(resource, values);

  const duplicate = await assertUnique(resource, payload, id, client);
  if (duplicate) {
    return { success: false, error: duplicate };
  }

  const { error } = await client.from(resource.table).update(payload).eq('id', id);
  if (error) {
    return { success: false, error: error.message };
  }

  const changes = diffPayload(before, payload);
  const audit = auditPayload(resource, values, payload);

  await logAdminAction(
    client,
    `${resource.table}.updated`,
    resource.table,
    id,
    changes,
    audit,
    resource.permission,
  );

  return { success: true, data: { id } };
}

/** Counts the live rows that reference one configuration row. */
export async function getReferencingCounts(
  resource: ConfigResource,
  id: string,
  client: SupabaseClient,
): Promise<Record<string, number>> {
  if (!resource.references || resource.references.length === 0) return {};

  const { data, error } = await client.rpc('admin_config_reference_counts', {
    p_resource: resource.referenceResource ?? resource.table,
    p_id: id,
  });

  if (error || !data || typeof data !== 'object') return {};

  const counts: Record<string, number> = {};
  for (const [key, value] of Object.entries(data as unknown as Record<string, unknown>)) {
    counts[key] = Number(value ?? 0);
  }
  return counts;
}

/** The references that stop a row from being deactivated. */
export function blockingReferences(
  resource: ConfigResource,
  counts: Record<string, number>,
): { key: string; label: string; count: number }[] {
  return (resource.references ?? [])
    .filter((reference) => reference.blocking !== false)
    .map((reference) => ({
      key: reference.key,
      label: reference.label,
      count: counts[reference.key] ?? 0,
    }))
    .filter((reference) => reference.count > 0);
}

/**
 * Deactivates one configuration row.
 *
 * The row is never deleted while live data points at it: the console counts
 * the references first and refuses, naming what is in the way.
 */
export async function deactivateRecord(
  resource: ConfigResource,
  id: string,
  reason: string,
  client: SupabaseClient,
): Promise<ActionResult<{ id: string }>> {
  if (!resource.softDelete) {
    return deleteRecord(resource, id, client);
  }

  const before = await getRecord(resource, id, client);
  if (!before) {
    return { success: false, error: 'That record no longer exists.' };
  }

  const counts = await getReferencingCounts(resource, id, client);
  const blocking = blockingReferences(resource, counts);
  if (blocking.length > 0) {
    const summary = blocking.map((reference) => `${reference.count} ${reference.label}`).join(', ');
    return {
      success: false,
      error: `This ${resource.singular} is still referenced by ${summary}. Deactivate it only once nothing uses it.`,
    };
  }

  const { error } = await client.from(resource.table).update({ is_active: false }).eq('id', id);
  if (error) {
    return { success: false, error: error.message };
  }

  await logAdminAction(
    client,
    `${resource.table}.deactivated`,
    resource.table,
    id,
    { is_active: true },
    { is_active: false, reason: reason || null },
    resource.permission,
  );

  return { success: true, data: { id } };
}

/**
 * Removes one configuration row.
 *
 * Only used for the tables that have no is_active column and that nothing
 * points at: feature flags and role permission grants.
 */
export async function deleteRecord(
  resource: ConfigResource,
  id: string,
  client: SupabaseClient,
): Promise<ActionResult<{ id: string }>> {
  const before = await getRecord(resource, id, client);
  if (!before) {
    return { success: false, error: 'That record no longer exists.' };
  }

  const counts = await getReferencingCounts(resource, id, client);
  const blocking = blockingReferences(resource, counts);
  if (blocking.length > 0) {
    const summary = blocking.map((reference) => `${reference.count} ${reference.label}`).join(', ');
    return {
      success: false,
      error: `This ${resource.singular} is still referenced by ${summary} and cannot be removed.`,
    };
  }

  const { error } = await client.from(resource.table).delete().eq('id', id);
  if (error) {
    return { success: false, error: error.message };
  }

  await logAdminAction(
    client,
    `${resource.table}.deleted`,
    resource.table,
    id,
    before,
    null,
    resource.permission,
  );

  return { success: true, data: { id } };
}

/** Reads the audit trail of one configuration row. */
export async function getAuditHistory(
  resource: ConfigResource,
  id: string,
  filters: AuditFilters = {},
  client?: SupabaseClient,
): Promise<AuditEntry[]> {
  const supabase = client ?? (await createClient());

  const { data, error } = await supabase.rpc('admin_audit_history', {
    p_entity_type: resource.table,
    p_entity_id: id,
    p_permission: resource.permission,
    p_limit: Math.min(Math.max(Number(filters.limit ?? 50), 1), 500),
    p_from: filters.from || null,
    p_to: filters.to || null,
    p_actor: filters.actor || null,
  });

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as AuditEntry[];
}
