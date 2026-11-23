// @vitest-environment node
//
// Calls the DEPLOYED payment-refund and payout-execute functions on a test
// project as a real admin and a real non-admin. Uses ids that do not exist,
// so nothing is written to the append-only money tables; the refund and
// payout logic itself is covered by the Deno tests and
// supabase/scripts/verify-money-controls.sql.
//
// Skipped unless SAFESHIFT_IT_CONFIG is set (see scripts/provision-integration-users.mjs).

import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { beforeAll, describe, expect, it } from 'vitest';

import { edgeErrorMessage } from '@/lib/money/money';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;

async function signIn(account: Account): Promise<SupabaseClient> {
  const client = createClient(config!.url, config!.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error } = await client.auth.signInWithPassword({ email: account.email, password: account.password });
  if (error) throw new Error(`sign-in failed for ${account.email}: ${error.message}`);
  return client;
}

async function call(client: SupabaseClient, fn: string, body: Record<string, unknown>, key?: string) {
  const { error } = await client.functions.invoke(fn, {
    body,
    headers: key ? { 'x-idempotency-key': key } : {},
  });
  if (!error) return { status: 200, message: '' };
  const status = (error as { context?: { status?: number } }).context?.status ?? 0;
  return { status, message: await edgeErrorMessage(error) };
}

describe.skipIf(!config)('deployed money functions', () => {
  let admin: SupabaseClient;
  let user: SupabaseClient;

  beforeAll(async () => {
    admin = await signIn(config!.admin);
    user = await signIn(config!.user);
  }, 30_000);

  it('payment-refund: admin reaches the payment lookup; non-admin is refused', async () => {
    const body = { payment_id: randomUUID(), amount: 1000, reason: 'integration check', refund_type: 'partial' };
    expect(await call(admin, 'payment-refund', body, `it-${randomUUID()}`)).toEqual({
      status: 404,
      message: 'Payment not found',
    });
    const refused = await call(user, 'payment-refund', body, `it-${randomUUID()}`);
    expect(refused.status).toBe(403);
  }, 30_000);

  it('payment-refund requires an idempotency key', async () => {
    const body = { payment_id: randomUUID(), amount: 1000, reason: 'integration check', refund_type: 'partial' };
    expect(await call(admin, 'payment-refund', body)).toEqual({
      status: 422,
      message: 'X-Idempotency-Key header is required',
    });
  }, 30_000);

  it('payout-execute: admin reaches the payout lookup; non-admin is refused', async () => {
    const body = { payout_id: randomUUID() };
    expect(await call(admin, 'payout-execute', body, `it-${randomUUID()}`)).toEqual({
      status: 404,
      message: 'Payout not found',
    });
    expect((await call(user, 'payout-execute', body, `it-${randomUUID()}`)).status).toBe(403);
  }, 30_000);

  it('refund and payout admin functions refuse a non-admin', async () => {
    const id = randomUUID();
    const checks = await Promise.all([
      user.rpc('admin_complete_refund', { p_refund_id: id, p_reference: 'REF-1' }),
      user.rpc('admin_fail_refund', { p_refund_id: id, p_reason: 'nope' }),
      user.rpc('admin_hold_payout', { p_payout_id: id, p_reason: 'nope' }),
      user.rpc('admin_retry_payout', { p_payout_id: id }),
      user.rpc('admin_payment_refunds', { p_payment_id: id }),
    ]);
    for (const result of checks) expect(result.error?.message).toMatch(/permission required/);
    // Service-only entry points are not callable by signed-in users at all.
    const service = await admin.rpc('reverse_failed_refund', { p_refund_id: id, p_reason: 'x' });
    expect(service.error).not.toBeNull();
  }, 30_000);
});
