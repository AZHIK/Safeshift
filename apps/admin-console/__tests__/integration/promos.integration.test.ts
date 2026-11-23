// @vitest-environment node
//
// Promo management against a real (test) Supabase project, signed in through
// the public API like the console. Skipped unless SAFESHIFT_IT_CONFIG is set
// (see scripts/provision-integration-users.mjs).

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { toSaveArgs, validatePromo, type PromoForm } from '@/lib/promos/promo';

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

describe.skipIf(!config)('promo management against Supabase', () => {
  let admin: SupabaseClient;
  let user: SupabaseClient;
  let promoId: string | null = null;
  const code = `IT${Date.now().toString(36).toUpperCase()}`;

  beforeAll(async () => {
    admin = await signIn(config!.admin);
    user = await signIn(config!.user);
  }, 30_000);

  afterAll(async () => {
    if (promoId) await admin.rpc('admin_delete_promo', { p_promo_id: promoId });
  }, 30_000);

  function form(patch: Partial<PromoForm> = {}): PromoForm {
    return {
      code,
      name: 'Integration promo',
      description: 'created by the console integration test',
      country_id: '',
      discount_type: 'capped_percentage',
      discount_value: 20,
      max_discount_amount: 5000,
      min_purchase_amount: 10000,
      currency_code: 'TZS',
      valid_from: new Date().toISOString(),
      valid_to: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
      total_redemption_limit: 50,
      per_user_redemption_limit: 1,
      new_users_only: false,
      applicable_vehicle_type_ids: [],
      applicable_city_ids: [],
      applicable_cargo_type_ids: [],
      is_active: true,
      rules: [
        { rule_type: 'first_job', value: '', description: '' },
        { rule_type: 'specific_day_of_week', value: '5', description: 'Fridays' },
      ],
      ...patch,
    };
  }

  it('creates, edits and lists a promo as an admin', async () => {
    expect(validatePromo(form())).toEqual([]);
    const created = toSaveArgs(form());
    const { data, error } = await admin.rpc('admin_save_promo', {
      p_promo_id: null,
      p_promo: created.promo,
      p_rules: created.rules,
    });
    expect(error).toBeNull();
    promoId = String(data);

    const edited = toSaveArgs(form({ name: 'Integration promo (edited)', rules: [{ rule_type: 'min_jobs_completed', value: '2', description: '' }] }));
    const update = await admin.rpc('admin_save_promo', { p_promo_id: promoId, p_promo: edited.promo, p_rules: edited.rules });
    expect(update.error).toBeNull();

    const { data: row } = await admin
      .from('promo_codes')
      .select('code, name, max_discount_amount, promo_code_eligibility_rules(rule_type, rule_value)')
      .eq('id', promoId)
      .single();
    expect(row).toMatchObject({ code, name: 'Integration promo (edited)', max_discount_amount: 5000 });
    expect(row?.promo_code_eligibility_rules).toEqual([{ rule_type: 'min_jobs_completed', rule_value: { min_jobs: 2 } }]);

    const summaries = await admin.rpc('admin_promo_summaries');
    expect(summaries.error).toBeNull();
    const history = await admin.rpc('admin_promo_redemptions', { p_promo_id: promoId, p_limit: 10, p_offset: 0 });
    expect(history.error).toBeNull();
    expect(history.data).toEqual([]);
  }, 60_000);

  it('rejects a duplicate code with a clear message', async () => {
    const dup = toSaveArgs(form());
    const { error } = await admin.rpc('admin_save_promo', { p_promo_id: null, p_promo: dup.promo, p_rules: [] });
    expect(error?.message).toBe(`promo code ${code} already exists`);
  }, 30_000);

  it('refuses a signed-in user without promotion permissions', async () => {
    const attempt = toSaveArgs(form({ code: `${code}X` }));
    const save = await user.rpc('admin_save_promo', { p_promo_id: null, p_promo: attempt.promo, p_rules: [] });
    expect(save.error?.message).toMatch(/manage_promotions permission required/);
    const summaries = await user.rpc('admin_promo_summaries');
    expect(summaries.error?.message).toMatch(/view_promotions permission required/);
    // RLS: a direct table write is refused too.
    const direct = await user.from('promo_codes').update({ is_active: false }).eq('id', promoId!).select('id');
    expect(direct.data ?? []).toEqual([]);
  }, 30_000);

  it('deletes the unredeemed promo', async () => {
    const { error } = await admin.rpc('admin_delete_promo', { p_promo_id: promoId });
    expect(error).toBeNull();
    promoId = null;
  }, 30_000);
});
