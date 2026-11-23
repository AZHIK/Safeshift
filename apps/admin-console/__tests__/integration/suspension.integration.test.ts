// @vitest-environment node
//
// Proves account suspension reaches Supabase Auth on a real (test) project:
// a suspended user cannot sign in, a reactivated one can. Skipped unless
// SAFESHIFT_IT_CONFIG is set (see scripts/provision-integration-users.mjs).

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;

function fresh(): SupabaseClient {
  return createClient(config!.url, config!.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
}

async function signIn(account: Account): Promise<{ client: SupabaseClient; error: string | null }> {
  const client = fresh();
  const { error } = await client.auth.signInWithPassword({ email: account.email, password: account.password });
  return { client, error: error?.message ?? null };
}

describe.skipIf(!config)('account suspension against Supabase Auth', () => {
  let admin: SupabaseClient;

  beforeAll(async () => {
    const result = await signIn(config!.admin);
    if (result.error) throw new Error(result.error);
    admin = result.client;
  }, 30_000);

  // Never leave the integration user suspended, whatever happens above.
  afterAll(async () => {
    await admin.rpc('admin_reactivate_account', { p_profile_id: config!.user.id, p_note: 'integration cleanup' });
  }, 30_000);

  it('a suspended user cannot sign in; a reactivated user can', async () => {
    const suspended = await admin.rpc('admin_suspend_account', {
      p_profile_id: config!.user.id,
      p_reason: 'Integration test suspension',
    });
    expect(suspended.error).toBeNull();

    const blocked = await signIn(config!.user);
    expect(blocked.error).toMatch(/banned/i);

    const reactivated = await admin.rpc('admin_reactivate_account', {
      p_profile_id: config!.user.id,
      p_note: 'Integration test done',
    });
    expect(reactivated.error).toBeNull();

    const allowed = await signIn(config!.user);
    expect(allowed.error).toBeNull();

    const history = await admin.rpc('admin_account_history', { p_entity_id: config!.user.id, p_limit: 5 });
    expect(history.error).toBeNull();
    const actions = ((history.data ?? []) as { action: string }[]).map((h) => h.action);
    expect(actions.slice(0, 2)).toEqual(['user_reactivated', 'user_suspended']);
  }, 60_000);

  it('an admin cannot suspend themselves', async () => {
    const { error } = await admin.rpc('admin_suspend_account', {
      p_profile_id: config!.admin.id,
      p_reason: 'should be refused',
    });
    expect(error?.message).toMatch(/your own account/);
  }, 30_000);

  it('a non-admin cannot suspend anyone', async () => {
    const { client, error } = await signIn(config!.user);
    expect(error).toBeNull();
    const attempt = await client.rpc('admin_suspend_account', {
      p_profile_id: config!.admin.id,
      p_reason: 'should be refused',
    });
    expect(attempt.error?.message).toMatch(/suspend_user permission required/);
  }, 30_000);
});
