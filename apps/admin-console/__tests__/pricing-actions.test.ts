import { beforeEach, describe, expect, it, vi } from 'vitest';

import { EMPTY_BASE_RATES, type PricingDraft } from '@/lib/pricing/draft';

import { createMockClient, type MockClient, type MockRpcHandler } from './helpers/mock-supabase';

const PLAN = '11111111-1111-4111-8111-111111111111';
const VERSION = '22222222-2222-4222-8222-222222222222';
const OLD_VERSION = '33333333-3333-4333-8333-333333333333';
const COUNTRY = '44444444-4444-4444-8444-444444444444';
const CITY = '55555555-5555-4555-8555-555555555555';
const VEHICLE = '66666666-6666-4666-8666-666666666666';

vi.mock('next/cache', () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));
vi.mock('@/lib/guard', () => ({ requireArea: vi.fn(async () => ({ role: 'super_admin' })) }));

class Redirect extends Error {
  constructor(public readonly url: string) {
    super(url);
  }
}
vi.mock('next/navigation', () => ({
  redirect: vi.fn((url: string) => {
    throw new Redirect(url);
  }),
}));

let currentClient: MockClient;
vi.mock('@/lib/supabase/server', () => ({ createClient: vi.fn(async () => currentClient) }));

function client(rpc: MockRpcHandler = () => ({ data: null, error: null })) {
  currentClient = createMockClient(() => ({ data: null, error: null }), rpc);
  return currentClient;
}

async function run(action: (fd: FormData) => Promise<void>, fields: Record<string, string>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) fd.set(k, v);
  try {
    await action(fd);
  } catch (error) {
    if (error instanceof Redirect) return decodeURIComponent(error.url);
    throw error;
  }
  throw new Error('action did not redirect');
}

const actions = () => import('@/app/(console)/pricing/actions');

function draft(patch: Partial<PricingDraft> = {}): PricingDraft {
  return {
    notes: 'Fuel',
    regulated_tariff_id: null,
    base_rates: { ...EMPTY_BASE_RATES, base_fare: 2000, per_km_rate: 500, per_min_rate: 40 },
    distance_tiers: [{ min_km: 0, max_km: null, per_km_rate: 500 }],
    weight_tiers: [],
    volume_tiers: [],
    cargo_surcharges: [],
    equipment_surcharges: [],
    time_multipliers: [],
    zone_multipliers: [],
    zones: [],
    vehicle_type_ids: [],
    ...patch,
  };
}

describe('pricing plan actions', () => {
  beforeEach(() => vi.resetModules());

  it('creates a plan, converting VAT percent to a fraction and lower-casing the code', async () => {
    const c = client(() => ({ data: PLAN, error: null }));
    const { createPricingPlanAction } = await actions();
    const url = await run(createPricingPlanAction, {
      country_id: COUNTRY,
      city_id: CITY,
      vehicle_type_id: VEHICLE,
      code: 'Dar-Pickup',
      name: 'Dar pickup',
      base_fare: '2000',
      per_km_rate: '500',
      per_min_rate: '40',
      minimum_charge: '5000',
      vat_percent: '18',
    });
    expect(c.rpcCalls[0].name).toBe('admin_create_pricing_plan');
    expect(c.rpcCalls[0].args).toMatchObject({
      p_code: 'dar-pickup',
      p_vat_rate: 0.18,
      p_base_fare: 2000,
      p_minimum_charge: 5000,
      p_currency_code: 'TZS',
    });
    expect(url).toBe(`/pricing/${PLAN}?ok=Plan created and version 1 published.`);
  });

  it('rejects an invalid code before calling the database', async () => {
    const c = client();
    const { createPricingPlanAction } = await actions();
    const url = await run(createPricingPlanAction, {
      country_id: COUNTRY,
      city_id: CITY,
      vehicle_type_id: VEHICLE,
      code: 'dar pickup!',
      name: 'Dar',
    });
    expect(c.rpcCalls).toEqual([]);
    expect(url).toContain('/pricing?error=Code must be lowercase');
  });

  it('updates plan details only — never rates', async () => {
    const c = client(() => ({ data: PLAN, error: null }));
    const { updatePricingPlanAction } = await actions();
    const url = await run(updatePricingPlanAction, {
      plan_id: PLAN,
      name: ' Renamed ',
      description: '',
      is_active: 'on',
    });
    expect(c.rpcCalls).toEqual([
      {
        name: 'admin_update_pricing_plan',
        args: { p_plan_id: PLAN, p_name: 'Renamed', p_description: null, p_is_active: true },
      },
    ]);
    expect(url).toBe(`/pricing/${PLAN}?ok=Plan details saved.`);
  });

  it('treats an unchecked active box as inactive', async () => {
    const c = client();
    const { updatePricingPlanAction } = await actions();
    await run(updatePricingPlanAction, { plan_id: PLAN, name: 'Plan' });
    expect(c.rpcCalls[0].args.p_is_active).toBe(false);
  });

  it('explains why a plan that priced quotes cannot be deleted', async () => {
    client(() => ({ data: null, error: { message: `pricing plan ${PLAN} has been used in quotes and cannot be deleted` } }));
    const { deletePricingPlanAction } = await actions();
    const url = await run(deletePricingPlanAction, { plan_id: PLAN });
    expect(url).toBe(
      `/pricing/${PLAN}?error=This plan has priced quotes, so it is kept for the record. Deactivate it instead.`,
    );
  });
});

describe('pricing draft actions', () => {
  beforeEach(() => vi.resetModules());

  it('opens a draft from the latest version and goes to the editor', async () => {
    const c = client(() => ({ data: VERSION, error: null }));
    const { createDraftAction } = await actions();
    const url = await run(createDraftAction, { plan_id: PLAN });
    expect(c.rpcCalls[0]).toEqual({
      name: 'admin_create_pricing_draft',
      args: { p_plan_id: PLAN, p_source_version_id: null },
    });
    expect(url).toBe(`/pricing/${PLAN}/versions/${VERSION}?ok=Draft created.`);
  });

  it('restores an older version as a draft', async () => {
    const c = client(() => ({ data: VERSION, error: null }));
    const { createDraftAction } = await actions();
    const url = await run(createDraftAction, { plan_id: PLAN, source_version_id: OLD_VERSION });
    expect(c.rpcCalls[0].args.p_source_version_id).toBe(OLD_VERSION);
    expect(url).toContain('Draft created from the older version');
  });

  it('shows the database reason when a draft is already open', async () => {
    client(() => ({ data: null, error: { message: 'version 3 is already an open draft; edit, publish or discard it first' } }));
    const { createDraftAction } = await actions();
    const url = await run(createDraftAction, { plan_id: PLAN });
    expect(url).toBe(`/pricing/${PLAN}?error=version 3 is already an open draft; edit, publish or discard it first`);
  });

  it('saves a valid draft with the normalised payload', async () => {
    const c = client(() => ({ data: VERSION, error: null }));
    const { saveDraftAction } = await actions();
    const result = await saveDraftAction(VERSION, draft({ notes: '  Fuel  ' }));
    expect(result).toEqual({ ok: true });
    expect(c.rpcCalls[0].name).toBe('admin_save_pricing_draft');
    expect(c.rpcCalls[0].args.p_version_id).toBe(VERSION);
    expect(c.rpcCalls[0].args.p_draft).toMatchObject({
      notes: 'Fuel',
      base_rates: { base_fare: 2000, per_km_rate: 500 },
      distance_tiers: [{ min_km: 0, max_km: null, per_km_rate: 500 }],
    });
  });

  it('refuses an invalid draft without calling the database', async () => {
    const c = client();
    const { saveDraftAction } = await actions();
    const result = await saveDraftAction(
      VERSION,
      draft({
        distance_tiers: [
          { min_km: 0, max_km: 10, per_km_rate: 1 },
          { min_km: 5, max_km: null, per_km_rate: 1 },
        ],
      }),
    );
    expect(c.rpcCalls).toEqual([]);
    expect(result.ok).toBe(false);
    expect(!result.ok && result.errors[0]).toContain('Distance tiers: Ranges overlap');
  });

  it('returns database errors from save so the editor keeps the edits', async () => {
    client(() => ({ data: null, error: { message: 'version 1 is published and cannot be changed; create a draft instead' } }));
    const { saveDraftAction } = await actions();
    expect(await saveDraftAction(VERSION, draft())).toEqual({
      ok: false,
      errors: ['version 1 is published and cannot be changed; create a draft instead'],
    });
  });

  it('publishes now when no start time is given', async () => {
    const c = client(() => ({ data: VERSION, error: null }));
    const { publishDraftAction } = await actions();
    const url = await run(publishDraftAction, { plan_id: PLAN, version_id: VERSION, effective_from: '' });
    expect(c.rpcCalls[0]).toEqual({
      name: 'admin_publish_pricing_draft',
      args: { p_version_id: VERSION, p_effective_from: null },
    });
    expect(url).toBe(`/pricing/${PLAN}?ok=Version published.`);
  });

  it('schedules with an ISO start time', async () => {
    const c = client(() => ({ data: VERSION, error: null }));
    const { publishDraftAction } = await actions();
    const url = await run(publishDraftAction, {
      plan_id: PLAN,
      version_id: VERSION,
      effective_from: '2026-12-01T06:00:00.000Z',
    });
    expect(c.rpcCalls[0].args.p_effective_from).toBe('2026-12-01T06:00:00.000Z');
    expect(url).toContain('Version scheduled');
  });

  it('stays on the editor when publishing fails', async () => {
    client(() => ({ data: null, error: { message: 'a version cannot start in the past' } }));
    const { publishDraftAction } = await actions();
    const url = await run(publishDraftAction, {
      plan_id: PLAN,
      version_id: VERSION,
      effective_from: '2020-01-01T00:00:00.000Z',
    });
    expect(url).toBe(`/pricing/${PLAN}/versions/${VERSION}?error=a version cannot start in the past`);
  });

  it('discards a draft', async () => {
    const c = client();
    const { discardDraftAction } = await actions();
    const url = await run(discardDraftAction, { plan_id: PLAN, version_id: VERSION });
    expect(c.rpcCalls[0]).toEqual({ name: 'admin_discard_pricing_draft', args: { p_version_id: VERSION } });
    expect(url).toBe(`/pricing/${PLAN}?ok=Draft discarded.`);
  });

  it('rejects a malformed version id', async () => {
    const c = client();
    const { discardDraftAction } = await actions();
    const url = await run(discardDraftAction, { plan_id: PLAN, version_id: 'nope' });
    expect(c.rpcCalls).toEqual([]);
    expect(url).toBe(`/pricing/${PLAN}?error=Missing or invalid version id.`);
  });
});

describe('previewQuoteAction', () => {
  beforeEach(() => vi.resetModules());

  it('prices a trip against the version', async () => {
    const c = client(() => ({ data: { total: 25075, currency_code: 'TZS' }, error: null }));
    const { previewQuoteAction } = await actions();
    const result = await previewQuoteAction(VERSION, {
      distance_km: 12.5,
      duration_min: 35,
      weight_kg: 300,
      volume_m3: 2,
      cargo_type_id: null,
      equipment_ids: [],
      zone_id: null,
      at: '2026-11-23T20:00:00.000Z',
    });
    expect(result).toEqual({ ok: true, quote: { total: 25075, currency_code: 'TZS' } });
    expect(c.rpcCalls[0]).toEqual({
      name: 'quote_preview',
      args: {
        p_pricing_plan_version_id: VERSION,
        p_distance_km: 12.5,
        p_duration_min: 35,
        p_weight_kg: 300,
        p_volume_m3: 2,
        p_cargo_type_id: null,
        p_equipment_ids: null,
        p_zone_id: null,
        p_at_time: '2026-11-23T20:00:00.000Z',
      },
    });
  });

  it('rejects negative inputs', async () => {
    const c = client();
    const { previewQuoteAction } = await actions();
    const result = await previewQuoteAction(VERSION, {
      distance_km: -1,
      duration_min: 0,
      weight_kg: 0,
      volume_m3: 0,
      cargo_type_id: null,
      equipment_ids: [],
      zone_id: null,
      at: '2026-11-23T20:00:00.000Z',
    });
    expect(c.rpcCalls).toEqual([]);
    expect(result).toEqual({ ok: false, error: 'Distance, duration, weight and volume must be 0 or more.' });
  });
});
