import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { PromoForm } from '@/lib/promos/promo';

import { createMockClient, type MockClient, type MockHandler, type MockRpcHandler } from './helpers/mock-supabase';

const PROMO = '11111111-1111-4111-8111-111111111111';

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

function client(rpc: MockRpcHandler = () => ({ data: null, error: null }), table: MockHandler = () => ({ data: null, error: null })) {
  currentClient = createMockClient(table, rpc);
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

const actions = () => import('@/app/(console)/promos/actions');

function form(patch: Partial<PromoForm> = {}): PromoForm {
  return {
    code: 'karibu20',
    name: 'Launch',
    description: '',
    country_id: '',
    discount_type: 'capped_percentage',
    discount_value: 20,
    max_discount_amount: 5000,
    min_purchase_amount: 0,
    currency_code: 'TZS',
    valid_from: '2026-12-01T00:00:00.000Z',
    valid_to: '2026-12-31T00:00:00.000Z',
    total_redemption_limit: 100,
    per_user_redemption_limit: 1,
    new_users_only: false,
    applicable_vehicle_type_ids: [],
    applicable_city_ids: [],
    applicable_cargo_type_ids: [],
    is_active: true,
    rules: [{ rule_type: 'min_jobs_completed', value: '3', description: '' }],
    ...patch,
  };
}

describe('promo actions', () => {
  beforeEach(() => vi.resetModules());

  it('creates a promo with normalised arguments', async () => {
    const c = client(() => ({ data: PROMO, error: null }));
    const { savePromoAction } = await actions();
    expect(await savePromoAction(null, form())).toEqual({ ok: true, id: PROMO });
    expect(c.rpcCalls[0].name).toBe('admin_save_promo');
    expect(c.rpcCalls[0].args.p_promo_id).toBeNull();
    expect(c.rpcCalls[0].args.p_promo).toMatchObject({ code: 'KARIBU20', max_discount_amount: 5000 });
    expect(c.rpcCalls[0].args.p_rules).toEqual([
      { rule_type: 'min_jobs_completed', rule_value: { min_jobs: 3 }, description: '' },
    ]);
  });

  it('refuses an invalid promo without calling the database', async () => {
    const c = client();
    const { savePromoAction } = await actions();
    const result = await savePromoAction(null, form({ max_discount_amount: null }));
    expect(c.rpcCalls).toEqual([]);
    expect(result).toEqual({ ok: false, errors: ['Set the maximum discount for a capped percentage.'] });
  });

  it('returns database errors such as a locked code', async () => {
    client(() => ({ data: null, error: { message: 'the code cannot change after it has been redeemed (4 times)' } }));
    const { savePromoAction } = await actions();
    expect(await savePromoAction(PROMO, form())).toEqual({
      ok: false,
      errors: ['the code cannot change after it has been redeemed (4 times)'],
    });
  });

  it('rejects a malformed promo id', async () => {
    const c = client();
    const { savePromoAction } = await actions();
    expect(await savePromoAction('nope', form())).toEqual({ ok: false, errors: ['Invalid promo.'] });
    expect(c.rpcCalls).toEqual([]);
  });

  it('pauses a promo and returns to the detail page when asked', async () => {
    const c = client();
    const { setPromoActiveAction } = await actions();
    const url = await run(setPromoActiveAction, { promo_id: PROMO, active: 'false', back: 'detail' });
    const update = c.requests.find((r) => r.table === 'promo_codes' && r.operation === 'update');
    expect(update?.payload).toEqual({ is_active: false });
    expect(update?.filters).toContainEqual({ column: 'id', operator: 'eq', value: PROMO });
    expect(url).toBe(`/promos/${PROMO}?ok=Promo paused. Customers can no longer apply it.`);
  });

  it('resumes from the list', async () => {
    client();
    const { setPromoActiveAction } = await actions();
    expect(await run(setPromoActiveAction, { promo_id: PROMO, active: 'true' })).toBe('/promos?ok=Promo resumed.');
  });

  it('keeps a redeemed promo and explains why', async () => {
    client(() => ({
      data: null,
      error: { message: 'this promo was redeemed 4 times and is kept for the record; deactivate it instead' },
    }));
    const { deletePromoAction } = await actions();
    const url = await run(deletePromoAction, { promo_id: PROMO });
    expect(url).toBe(
      `/promos/${PROMO}?error=this promo was redeemed 4 times and is kept for the record; deactivate it instead`,
    );
  });

  it('deletes an unredeemed promo', async () => {
    const c = client();
    const { deletePromoAction } = await actions();
    expect(await run(deletePromoAction, { promo_id: PROMO })).toBe('/promos?ok=Promo deleted.');
    expect(c.rpcCalls[0]).toEqual({ name: 'admin_delete_promo', args: { p_promo_id: PROMO } });
  });
});
