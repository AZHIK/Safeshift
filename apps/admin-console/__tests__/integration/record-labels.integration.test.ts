// @vitest-environment node
//
// Readable names for reference fields (migrations 0184/0185) against the
// hosted test project. Skipped unless SAFESHIFT_IT_CONFIG is set.

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { beforeAll, describe, expect, it } from 'vitest';

import { verifiedAdmin } from '../helpers/verified-admin';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-/i;

describe.skipIf(!config)('record names against Supabase', () => {
  let admin: SupabaseClient;
  let user: SupabaseClient;

  beforeAll(async () => {
    admin = verifiedAdmin(config!);
    user = createClient(config!.url, config!.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error } = await user.auth.signInWithPassword({ email: config!.user.email, password: config!.user.password });
    if (error) throw error;
  }, 30_000);

  it('offers city names, not ids, for a pricing plan', async () => {
    const { data, error } = await admin.rpc('admin_record_options', { p_table: 'pricing_plans', p_column: 'city_id' });
    expect(error).toBeNull();
    const { options } = data as { options: { value: string; label: string }[] };
    expect(options.length).toBeGreaterThan(0);
    expect(options[0].value).toMatch(UUID);
    expect(options[0].label).not.toMatch(UUID);
  }, 30_000);

  it('narrows choices with a search', async () => {
    const { data } = await admin.rpc('admin_record_options', { p_table: 'cities', p_column: 'country_id', p_search: 'tanz' });
    const { options } = data as { options: { label: string }[] };
    expect(options.every((o) => /tanz/i.test(o.label))).toBe(true);
  }, 30_000);

  it('names the admin through the console names lookup', async () => {
    const { data, error } = await admin.rpc('admin_entity_names', { p_table: 'profiles', p_ids: [config!.admin.id] });
    expect(error).toBeNull();
    expect((data as Record<string, string>)[config!.admin.id]).toBeTruthy();
  }, 30_000);

  it('refuses a normal user', async () => {
    const options = await user.rpc('admin_record_options', { p_table: 'pricing_plans', p_column: 'city_id' });
    expect(options.error?.code).toBe('42501');
    const names = await user.rpc('admin_entity_names', { p_table: 'profiles', p_ids: [config!.admin.id] });
    expect(names.error?.code).toBe('42501');
  }, 30_000);
});
