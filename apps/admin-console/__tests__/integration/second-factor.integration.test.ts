// @vitest-environment node
//
// Email / SMS second factor against the DEPLOYED admin-otp function, signed in
// with a password only (aal1). Until BREVO_API_KEY / MESEJI_API_KEY are set
// as project secrets, sending is expected to fail cleanly and the unsent code
// must be discarded (so an immediate retry is not rate-limited).
// Skipped unless SAFESHIFT_IT_CONFIG is set.

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { beforeAll, describe, expect, it } from 'vitest';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;

async function send(client: SupabaseClient, channel: string) {
  const { data, error } = await client.functions.invoke('admin-otp', { body: { channel } });
  if (!error) return { status: 200, message: '', data };
  const e = error as { context?: Response };
  const status = e.context?.status ?? 0;
  let message = '';
  try {
    message = ((await e.context?.json()) as { error?: { message?: string } })?.error?.message ?? '';
  } catch {
    message = '';
  }
  return { status, message, data: null };
}

describe.skipIf(!config)('email and SMS second factor (deployed)', () => {
  let admin: SupabaseClient;

  beforeAll(async () => {
    admin = createClient(config!.url, config!.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { error } = await admin.auth.signInWithPassword({ email: config!.admin.email, password: config!.admin.password });
    if (error) throw error;
  }, 30_000);

  it('a password-only session holds no staff permissions', async () => {
    const { data } = await admin.rpc('has_permission', { permission_key: 'manage_admins' });
    expect(data).toBe(false);
    const status = await admin.rpc('admin_second_factor_status');
    expect(status.data).toMatchObject({ verified: false, email: config!.admin.email });
  }, 30_000);

  it('email: the code is issued, and an unsendable code is discarded', async () => {
    const first = await send(admin, 'email');
    if (first.status === 200) {
      // Brevo is configured: the code went out by email.
      expect(first.data).toMatchObject({ data: { sent: true, channel: 'email' } });
      return;
    }
    expect(first.message).toMatch(/Brevo/i);
    // Discarded, so an immediate retry is not refused by the one-minute limit.
    const second = await send(admin, 'email');
    expect(second.status).not.toBe(429);
  }, 30_000);

  it('sms: refused clearly when the account has no phone number', async () => {
    const result = await send(admin, 'sms');
    if (result.status === 200) return; // a phone and Meseji are configured
    expect(result.message).toMatch(/no phone number|Meseji/i);
  }, 30_000);

  it('a guessed code does not verify and grants nothing', async () => {
    const { error } = await admin.rpc('admin_verify_second_factor', { p_code: '000000' });
    // No live code for this session (or a wrong one): either way, no access.
    expect(error === null || /expired|attempts/.test(error.message)).toBe(true);
    const { data } = await admin.rpc('has_permission', { permission_key: 'manage_admins' });
    expect(data).toBe(false);
  }, 30_000);
});
