// @vitest-environment node
//
// End-to-end pricing editor test against a real (test) Supabase project.
// Signs in through the public API exactly like the console, so the real
// has_permission gate, RLS and triggers are exercised.
//
// Skipped unless SAFESHIFT_IT_CONFIG points at the file written by
// scripts/provision-integration-users.mjs:
//
//   SAFESHIFT_IT_CONFIG=~/.config/safeshift/integration-users.json pnpm test:integration

import { existsSync, readFileSync } from 'node:fs';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { EMPTY_BASE_RATES, toSavePayload, validateDraft, type PricingDraft } from '@/lib/pricing/draft';

type Account = { id: string; email: string; password: string };
type Config = { url: string; anonKey: string; admin: Account; user: Account };

const configPath = process.env.SAFESHIFT_IT_CONFIG;
const config: Config | null =
  configPath && existsSync(configPath) ? (JSON.parse(readFileSync(configPath, 'utf8')) as Config) : null;

async function signIn(account: Account): Promise<SupabaseClient> {
  const client = createClient(config!.url, config!.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.auth.signInWithPassword({ email: account.email, password: account.password });
  if (error) throw new Error(`sign-in failed for ${account.email}: ${error.message}`);
  return client;
}

function must<T>(result: { data: T | null; error: { message: string } | null }, what: string): T {
  if (result.error) throw new Error(`${what}: ${result.error.message}`);
  return result.data as T;
}

describe.skipIf(!config)('pricing editor against Supabase', () => {
  let admin: SupabaseClient;
  let user: SupabaseClient;
  let planId: string | null = null;

  beforeAll(async () => {
    admin = await signIn(config!.admin);
    user = await signIn(config!.user);
  }, 30_000);

  afterAll(async () => {
    if (planId) await admin.rpc('admin_delete_pricing_plan', { p_plan_id: planId });
  }, 30_000);

  it('runs the full draft → preview → publish → rollback flow as an admin', async () => {
    const city = must(
      await admin.from('cities').select('id, country_id').eq('is_active', true).limit(1).single(),
      'load city',
    ) as { id: string; country_id: string };
    const vehicle = must(
      await admin
        .from('vehicle_types')
        .select('id')
        .eq('is_active', true)
        .or(`country_id.is.null,country_id.eq.${city.country_id}`)
        .limit(1)
        .single(),
      'load vehicle type',
    ) as { id: string };

    planId = must(
      await admin.rpc('admin_create_pricing_plan', {
        p_country_id: city.country_id,
        p_city_id: city.id,
        p_vehicle_type_id: vehicle.id,
        p_code: `it-pricing-${Date.now().toString(36)}`,
        p_name: 'Integration pricing plan',
        p_description: null,
        p_service_zone_id: null,
        p_currency_code: 'TZS',
        p_base_fare: 1000,
        p_per_km_rate: 500,
        p_per_min_rate: 50,
        p_minimum_charge: 3000,
        p_vat_rate: 0.18,
      }),
      'create plan',
    ) as string;

    const versionsAfterCreate = must(
      await admin.from('pricing_plan_versions').select('id, version_number, published_at').eq('pricing_plan_id', planId),
      'load versions',
    ) as { id: string; version_number: number; published_at: string | null }[];
    expect(versionsAfterCreate).toHaveLength(1);
    const v1 = versionsAfterCreate[0];
    expect(v1.published_at).not.toBeNull();

    // A published version is immutable, even for a super admin.
    const blocked = await admin.rpc('admin_save_pricing_draft', {
      p_version_id: v1.id,
      p_draft: { base_rates: { base_fare: 1, per_km_rate: 1, per_min_rate: 1 } },
    });
    expect(blocked.error?.message).toMatch(/is published and cannot be changed/);

    // Draft, save everything, preview the draft.
    const v2 = must(await admin.rpc('admin_create_pricing_draft', { p_plan_id: planId }), 'create draft') as string;
    const draft: PricingDraft = {
      notes: 'Integration test',
      regulated_tariff_id: null,
      base_rates: { ...EMPTY_BASE_RATES, base_fare: 2000, per_km_rate: 600, per_min_rate: 40, loading_fee: 1500 },
      distance_tiers: [
        { min_km: 0, max_km: 10, per_km_rate: 700 },
        { min_km: 10, max_km: null, per_km_rate: 500 },
      ],
      weight_tiers: [{ min_kg: 500, max_kg: null, surcharge_type: 'flat_fee', surcharge_value: 5000 }],
      volume_tiers: [],
      cargo_surcharges: [],
      equipment_surcharges: [],
      time_multipliers: [],
      zone_multipliers: [],
      zones: [],
      vehicle_type_ids: [],
    };
    expect(validateDraft(draft)).toEqual([]);
    must(await admin.rpc('admin_save_pricing_draft', { p_version_id: v2, p_draft: toSavePayload(draft) }), 'save draft');

    const preview = must(
      await admin.rpc('quote_preview', {
        p_pricing_plan_version_id: v2,
        p_distance_km: 12,
        p_duration_min: 30,
        p_weight_kg: 100,
        p_volume_m3: 1,
        p_cargo_type_id: null,
        p_equipment_ids: null,
        p_zone_id: null,
        p_at_time: new Date().toISOString(),
      }),
      'preview',
    ) as Record<string, number>;
    // 10 km × 700 + 2 km × 500 = 8 000; base 2 000; time 30 × 40 = 1 200.
    expect(Number(preview.distance_charge)).toBe(8000);
    expect(Number(preview.base_fare)).toBe(2000);
    expect(Number(preview.time_charge)).toBe(1200);

    // Publish now: version 2 becomes active and supersedes version 1.
    must(await admin.rpc('admin_publish_pricing_draft', { p_version_id: v2, p_effective_from: null }), 'publish');
    const active = must(
      await admin.rpc('active_pricing_plan_version', { p_pricing_plan_id: planId, p_at_time: new Date().toISOString() }),
      'active version',
    );
    expect(active).toBe(v2);

    // Roll back: draft from version 1 carries its rates, then discard it.
    const v3 = must(
      await admin.rpc('admin_create_pricing_draft', { p_plan_id: planId, p_source_version_id: v1.id }),
      'rollback draft',
    ) as string;
    const rates = must(
      await admin.from('pricing_plan_base_rates').select('base_fare').eq('pricing_plan_version_id', v3).single(),
      'rollback rates',
    ) as { base_fare: number };
    expect(Number(rates.base_fare)).toBe(1000);
    must(await admin.rpc('admin_discard_pricing_draft', { p_version_id: v3 }), 'discard');

    // Renaming never creates a version.
    must(
      await admin.rpc('admin_update_pricing_plan', {
        p_plan_id: planId,
        p_name: 'Integration plan (renamed)',
        p_description: null,
        p_is_active: true,
      }),
      'rename',
    );
    const finalVersions = must(
      await admin.from('pricing_plan_versions').select('id').eq('pricing_plan_id', planId),
      'final versions',
    ) as unknown[];
    expect(finalVersions).toHaveLength(2);
  }, 60_000);

  it('refuses a signed-in user without manage_pricing', async () => {
    expect(planId).not.toBeNull();
    const draft = await user.rpc('admin_create_pricing_draft', { p_plan_id: planId });
    expect(draft.error?.message).toMatch(/manage_pricing permission required/);

    const publish = await user.rpc('admin_publish_pricing_draft', {
      p_version_id: '00000000-0000-4000-8000-000000000000',
      p_effective_from: null,
    });
    expect(publish.error?.message).toMatch(/manage_pricing permission required/);
  }, 30_000);

  it('refuses anonymous callers outright', async () => {
    const anon = createClient(config!.url, config!.anonKey, { auth: { persistSession: false } });
    const result = await anon.rpc('admin_create_pricing_draft', { p_plan_id: planId });
    expect(result.error).not.toBeNull();
  }, 30_000);
});
