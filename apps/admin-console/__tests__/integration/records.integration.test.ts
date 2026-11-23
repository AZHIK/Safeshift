// @vitest-environment node
//
// Generic record management (migrations 0182/0183) against the hosted test
// project, as the 2FA-verified integration admin and as a normal user.
// Skipped unless SAFESHIFT_IT_CONFIG is set.

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { verifiedAdmin } from '../helpers/verified-admin';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;

describe.skipIf(!config)('record management against Supabase', () => {
  let admin: SupabaseClient;
  let user: SupabaseClient;
  let createdId: string | null = null;
  const code = `Q${Date.now().toString(36).slice(-2).toUpperCase()}`.slice(0, 3);

  beforeAll(async () => {
    admin = verifiedAdmin(config!);
    user = createClient(config!.url, config!.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error } = await user.auth.signInWithPassword({ email: config!.user.email, password: config!.user.password });
    if (error) throw error;
  }, 30_000);

  afterAll(async () => {
    if (createdId) await admin.rpc('admin_record_delete', { p_table: 'currencies', p_key: { id: createdId } });
  });

  it('lists every table and marks money tables append-only', async () => {
    const { data, error } = await admin.rpc('admin_record_tables');
    expect(error).toBeNull();
    const rows = data as { table_name: string; writable: boolean; write_block: string | null }[];
    expect(rows.length).toBeGreaterThan(100);
    expect(rows.find((t) => t.table_name === 'cities')?.writable).toBe(true);
    expect(rows.find((t) => t.table_name === 'payments')?.write_block).toMatch(/append-only/);
  }, 30_000);

  it('creates, edits, finds and deletes a record', async () => {
    const created = await admin.rpc('admin_record_insert', {
      p_table: 'currencies',
      p_values: { code, name: 'Integration Dollar', symbol: 'I$', decimal_places: 2, is_active: false },
    });
    expect(created.error).toBeNull();
    createdId = (created.data as { id: string }).id;

    const edited = await admin.rpc('admin_record_update', {
      p_table: 'currencies', p_key: { id: createdId }, p_values: { name: `Integration Renamed ${code}` },
    });
    expect(edited.error).toBeNull();
    expect((edited.data as { name: string }).name).toBe(`Integration Renamed ${code}`);

    const found = await admin.rpc('admin_record_list', {
      p_table: 'currencies', p_search: `Integration Renamed ${code}`, p_order: null, p_desc: true, p_limit: 10, p_offset: 0,
    });
    expect((found.data as { total: number }).total).toBe(1);

    const columns = await admin.rpc('admin_record_columns', { p_table: 'regulated_tariffs' });
    const structure = (columns.data as { column_name: string; enum_values: string[] | null }[])
      .find((c) => c.column_name === 'tariff_structure');
    expect(structure?.enum_values).toContain('distance_band');

    const removed = await admin.rpc('admin_record_delete', { p_table: 'currencies', p_key: { id: createdId } });
    expect(removed.error).toBeNull();
    createdId = null;
  }, 30_000);

  it('refuses raw edits to money records and deletes of records still in use', async () => {
    const money = await admin.rpc('admin_record_insert', { p_table: 'payments', p_values: { amount: 1 } });
    expect(money.error?.message).toMatch(/append-only/);
    const { data: city } = await admin.from('cities').select('id').limit(1).single();
    const inUse = await admin.rpc('admin_record_delete', { p_table: 'cities', p_key: { id: city!.id } });
    expect(inUse.error?.message).toMatch(/other records still use this one/);
  }, 30_000);

  it('gives a normal user nothing', async () => {
    for (const [fn, args] of [
      ['admin_record_tables', {}],
      ['admin_record_list', { p_table: 'profiles', p_search: null, p_order: null, p_desc: true, p_limit: 5, p_offset: 0 }],
      ['admin_record_insert', { p_table: 'currencies', p_values: { code: 'ZZX' } }],
      ['admin_delete_account', { p_profile_id: config!.admin.id, p_reason: 'nope' }],
    ] as const) {
      const { error } = await user.rpc(fn, args);
      expect(error?.message, fn).toMatch(/permission|required/);
    }
  }, 30_000);
});
