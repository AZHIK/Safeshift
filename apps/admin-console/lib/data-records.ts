/**
 * Helpers for the generic record pages (/data) and the row action menus.
 *
 * The database decides what may be written (admin_record_* functions,
 * migration 0182); these helpers only shape keys and form values.
 */

import { redirect } from 'next/navigation';
import { cache } from 'react';

import { getAdminSession } from '@/lib/auth';

import { getCallerPermissions } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';

export type RecordKey = Record<string, string>;

export type RecordColumn = {
  column_name: string;
  data_type: string;
  is_nullable: boolean;
  has_default: boolean;
  is_primary_key: boolean;
  is_generated: boolean;
  references_table: string | null;
  enum_values: string[] | null;
};

export type InputKind = 'boolean' | 'enum' | 'json' | 'number' | 'date' | 'timestamp' | 'longtext' | 'text';

const TABLE_RE = /^[a-z_][a-z0-9_]{0,62}$/;

export function isTableName(value: string): boolean {
  return TABLE_RE.test(value);
}

/** URL-safe token for a primary key ({"id": "..."} or composite). */
export function encodeKey(key: RecordKey): string {
  return Buffer.from(JSON.stringify(key), 'utf8').toString('base64url');
}

export function decodeKey(token: string): RecordKey | null {
  try {
    const value = JSON.parse(Buffer.from(token, 'base64url').toString('utf8')) as unknown;
    if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0 || entries.some(([, v]) => typeof v !== 'string' && typeof v !== 'number')) return null;
    return Object.fromEntries(entries.map(([k, v]) => [k, String(v)]));
  } catch {
    return null;
  }
}

/** The key of a row, from its primary-key columns. */
export function keyOf(row: Record<string, unknown>, primaryKey: string[]): RecordKey {
  return Object.fromEntries(primaryKey.map((c) => [c, String(row[c] ?? '')]));
}

export function recordHref(table: string, key: RecordKey | string, suffix = ''): string {
  const k = typeof key === 'string' ? { id: key } : key;
  return `/data/${table}/${encodeKey(k)}${suffix}`;
}

export function inputKind(column: RecordColumn): InputKind {
  const t = column.data_type.toLowerCase();
  if (t === 'boolean') return 'boolean';
  if (column.enum_values?.length) return 'enum';
  if (t === 'json' || t === 'jsonb' || t.endsWith('[]')) return 'json';
  if (/^(smallint|integer|bigint|numeric|real|double precision|decimal)/.test(t)) return 'number';
  if (t === 'date') return 'date';
  if (t.startsWith('timestamp')) return 'timestamp';
  if (t === 'text' && !column.is_primary_key) return 'longtext';
  return 'text';
}

/** A value as the form shows it. */
export function formValue(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') return JSON.stringify(value, null, 2);
  return String(value);
}

export class FormValueError extends Error {}

/**
 * Turns submitted fields ("f:<column>") into the JSON object the database
 * functions take. On create, blank fields are left out so defaults apply;
 * on edit, a blank nullable field becomes null and a blank required field
 * is left unchanged. Keys and generated columns are never sent on edit.
 */
export function parseRecordForm(
  columns: RecordColumn[],
  formData: FormData,
  mode: 'create' | 'edit',
): Record<string, unknown> {
  const values: Record<string, unknown> = {};
  for (const column of columns) {
    if (column.is_generated) continue;
    if (mode === 'edit' && column.is_primary_key) continue;
    const name = `f:${column.column_name}`;
    if (!formData.has(name)) continue;
    const raw = String(formData.get(name) ?? '');
    const kind = inputKind(column);
    if (raw.trim() === '') {
      if (mode === 'edit' && column.is_nullable) values[column.column_name] = null;
      continue;
    }
    switch (kind) {
      case 'boolean':
        values[column.column_name] = raw === 'true';
        break;
      case 'number': {
        const n = Number(raw);
        if (!Number.isFinite(n)) throw new FormValueError(`${column.column_name} must be a number`);
        values[column.column_name] = n;
        break;
      }
      case 'json':
        try {
          values[column.column_name] = JSON.parse(raw);
        } catch {
          throw new FormValueError(`${column.column_name} must be valid JSON`);
        }
        break;
      default:
        values[column.column_name] = raw;
    }
  }
  return values;
}

/**
 * Tables staff may edit with their own area's permission (mirrors
 * private.record_domain_permission, migration 0183). Everything else needs
 * manage_records.
 */
export const TABLE_PERMISSION: Readonly<Record<string, string>> = {
  regulated_tariffs: 'manage_regulated_tariffs',
  vehicle_types: 'manage_vehicle_catalog',
  cargo_types: 'manage_cargo_catalog',
  cargo_categories: 'manage_cargo_catalog',
  promo_codes: 'manage_promotions',
  promo_code_eligibility_rules: 'manage_promotions',
  fleets: 'manage_fleets',
  fleet_members: 'manage_fleets',
  fleet_vehicles: 'manage_fleets',
  support_categories: 'manage_tickets',
  announcements: 'send_notification',
};

export type RecordAccess = {
  /** The caller holds manage_records (every table). */
  canManage: boolean;
  /** Tables the caller may open and edit through the record pages. */
  allowed: (table: string) => boolean;
  /** Tables whose rows cannot be edited raw, with the reason. */
  blocked: Map<string, string>;
};

/** Per-request: which tables the caller may manage, and which are append-only. */
export const getRecordAccess = cache(async (): Promise<RecordAccess> => {
  const { permissions } = await getCallerPermissions();
  const domain = (table: string) => Boolean(TABLE_PERMISSION[table] && permissions.has(TABLE_PERMISSION[table]));
  if (!permissions.has('manage_records')) return { canManage: false, allowed: domain, blocked: new Map() };
  const { data, error } = await (await createClient()).rpc('admin_record_tables');
  const blocked = new Map<string, string>();
  if (!error) {
    for (const row of (data ?? []) as { table_name: string; write_block: string | null }[]) {
      if (row.write_block) blocked.set(row.table_name, row.write_block);
    }
  }
  const canManage = !error;
  return { canManage, allowed: (table) => canManage || domain(table), blocked };
});

/** Guard for /data/<table> pages and actions: manage_records or the table's own permission. */
export async function requireRecordTable(table: string): Promise<void> {
  if (!(await getAdminSession())) redirect('/login?error=Sign in with an admin account.');
  if (!(await getRecordAccess()).allowed(table)) redirect('/dashboard');
}
