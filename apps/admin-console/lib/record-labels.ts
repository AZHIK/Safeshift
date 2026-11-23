/**
 * Readable names for reference (foreign-key) fields on the record pages.
 * The database decides the name of each row (admin_record_options /
 * admin_record_labels / admin_record_display, migration 0184).
 */

import type { RecordColumn } from '@/lib/data-records';
import { entityTable } from '@/lib/entity-links';
import { createClient } from '@/lib/supabase/server';

export type ReferenceOption = { value: string; label: string };
export type ReferenceChoices = { options: ReferenceOption[]; more: boolean };
/** column → value → name */
export type ReferenceLabels = Record<string, Record<string, string>>;

/** How many choices a dropdown loads before it needs a search. */
export const OPTION_LIMIT = 200;

/** Columns that point at another table. */
export function referenceColumns(columns: RecordColumn[]): RecordColumn[] {
  return columns.filter((c) => c.references_table && !c.is_generated);
}

/** The referenced table without its schema, or null for tables outside public. */
export function referencedTable(column: RecordColumn): string | null {
  const ref = column.references_table;
  if (!ref) return null;
  if (!ref.includes('.')) return ref;
  return ref.startsWith('public.') ? ref.slice('public.'.length) : null;
}

/** Two rows with the same name get a short id suffix so they can be told apart. */
export function disambiguate(options: ReferenceOption[]): ReferenceOption[] {
  const counts = new Map<string, number>();
  for (const o of options) counts.set(o.label, (counts.get(o.label) ?? 0) + 1);
  return options.map((o) =>
    (counts.get(o.label) ?? 0) > 1 ? { ...o, label: `${o.label} (#${o.value.replace(/-/g, '').slice(-4)})` } : o,
  );
}

function asChoices(data: unknown): ReferenceChoices {
  const d = (data ?? {}) as { options?: ReferenceOption[]; more?: boolean };
  return { options: disambiguate(d.options ?? []), more: Boolean(d.more) };
}

/** Choices for one reference column, optionally narrowed by a search. */
export async function searchReferenceOptions(table: string, column: string, search: string | null): Promise<ReferenceChoices> {
  const { data, error } = await (await createClient()).rpc('admin_record_options', {
    p_table: table,
    p_column: column,
    p_search: search,
    p_limit: OPTION_LIMIT,
  });
  if (error) throw new Error(error.message);
  return asChoices(data);
}

/** Names for the reference values in some rows of a table. */
export async function loadReferenceLabels(
  table: string,
  columns: RecordColumn[],
  rows: Record<string, unknown>[],
): Promise<ReferenceLabels> {
  const values: Record<string, string[]> = {};
  for (const c of referenceColumns(columns)) {
    const set = new Set<string>();
    for (const row of rows) {
      const v = row[c.column_name];
      if (v !== null && v !== undefined && v !== '' && typeof v !== 'object') set.add(String(v));
    }
    if (set.size) values[c.column_name] = [...set];
  }
  if (Object.keys(values).length === 0) return {};
  const { data, error } = await (await createClient()).rpc('admin_record_labels', { p_table: table, p_values: values });
  return error ? {} : ((data ?? {}) as ReferenceLabels);
}

/**
 * Dropdown choices for every reference column of a form. The current value
 * is always among the choices, even when it is not in the first page.
 */
export async function loadReferenceChoices(
  table: string,
  columns: RecordColumn[],
  current: Record<string, unknown> = {},
): Promise<Record<string, ReferenceChoices>> {
  const refs = referenceColumns(columns);
  const [labels, ...choices] = await Promise.all([
    loadReferenceLabels(table, refs, [current]),
    ...refs.map((c) =>
      searchReferenceOptions(table, c.column_name, null).catch((): ReferenceChoices => ({ options: [], more: true })),
    ),
  ]);
  const result: Record<string, ReferenceChoices> = {};
  refs.forEach((c, i) => {
    const choice = choices[i];
    const value = current[c.column_name];
    if (value !== null && value !== undefined && value !== '') {
      const v = String(value);
      if (!choice.options.some((o) => o.value === v)) {
        choice.options = [{ value: v, label: labels[c.column_name]?.[v] ?? v }, ...choice.options];
      }
    }
    result[c.column_name] = choice;
  });
  return result;
}

/** Names for a table's own rows, by id. */
export async function loadRecordNames(table: string, ids: string[]): Promise<Record<string, string>> {
  if (ids.length === 0) return {};
  const { data, error } = await (await createClient()).rpc('admin_record_display', { p_table: table, p_ids: ids });
  return error ? {} : ((data ?? {}) as Record<string, string>);
}

/**
 * Names for records shown on console screens, for any console staff member
 * (admin_entity_names, migration 0185). Missing names fall back to the id.
 */
export async function loadEntityNames(
  wanted: Record<string, (string | null | undefined)[]>,
): Promise<Record<string, Record<string, string>>> {
  const supabase = await createClient();
  const entries = await Promise.all(
    Object.entries(wanted).map(async ([table, ids]) => {
      const unique = [...new Set(ids.filter((id): id is string => Boolean(id)))];
      if (unique.length === 0) return [table, {}] as const;
      const { data, error } = await supabase.rpc('admin_entity_names', { p_table: table, p_ids: unique });
      return [table, error ? {} : ((data ?? {}) as Record<string, string>)] as const;
    }),
  );
  return Object.fromEntries(entries);
}

/** Names for audited (entity_type, entity_id) pairs: returns a lookup. */
export async function loadAuditedNames(
  rows: { entity_type?: string | null; entity_id?: string | null }[],
): Promise<(type: unknown, id: unknown) => string | null> {
  const wanted: Record<string, string[]> = {};
  for (const r of rows) {
    const table = entityTable(r.entity_type);
    if (table && r.entity_id) (wanted[table] ??= []).push(r.entity_id);
  }
  const names = await loadEntityNames(wanted);
  return (type, id) => {
    const table = entityTable(type);
    return table && id ? (names[table]?.[String(id)] ?? null) : null;
  };
}
