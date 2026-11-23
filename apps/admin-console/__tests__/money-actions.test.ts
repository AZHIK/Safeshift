import { beforeEach, describe, expect, it, vi } from 'vitest';

import { edgeErrorMessage, refundableAmount, validateRefund } from '@/lib/money/money';

import {
  createMockClient,
  type MockClient,
  type MockFunctionsHandler,
  type MockHandler,
  type MockRpcHandler,
} from './helpers/mock-supabase';

const PAYMENT = '11111111-1111-4111-8111-111111111111';
const REFUND = '22222222-2222-4222-8222-222222222222';
const BATCH = '33333333-3333-4333-8333-333333333333';
const PAYOUT = '44444444-4444-4444-8444-444444444444';
const PAYOUT_2 = '55555555-5555-4555-8555-555555555555';
const COUNTRY = '66666666-6666-4666-8666-666666666666';

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

function client(
  table: MockHandler = () => ({ data: null, error: null }),
  rpc: MockRpcHandler = () => ({ data: null, error: null }),
  fns: MockFunctionsHandler = () => ({ data: { data: { status: 'succeeded' } }, error: null }),
) {
  currentClient = createMockClient(table, rpc, fns);
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

/** Shaped like supabase-js FunctionsHttpError: the body is on context. */
function edgeError(message: string) {
  return { message: 'Edge Function returned a non-2xx status code', context: { json: async () => ({ data: null, error: { code: 'x', message } }) } };
}

describe('money helpers', () => {
  it('computes what is still refundable, ignoring failed refunds', () => {
    expect(refundableAmount(50000, [])).toBe(50000);
    expect(
      refundableAmount('50000.00', [
        { amount: '20000', status: 'succeeded' },
        { amount: 10000, status: 'processing' },
        { amount: 15000, status: 'failed' },
      ]),
    ).toBe(20000);
    expect(refundableAmount(100, [{ amount: 150, status: 'succeeded' }])).toBe(0);
  });

  it('validates a refund request', () => {
    const ok = { amount: 1000, reason: 'Damaged item', refund_type: 'partial' as const };
    expect(validateRefund(ok, 5000)).toBeNull();
    expect(validateRefund({ ...ok, amount: 0 }, 5000)).toBe('Enter an amount greater than 0.');
    expect(validateRefund({ ...ok, amount: 10.555 }, 5000)).toBe('Use at most two decimal places.');
    expect(validateRefund({ ...ok, amount: 6000 }, 5000)).toBe('At most 5000 can still be refunded.');
    expect(validateRefund({ ...ok, refund_type: 'full' }, 5000)).toBe('A full refund must be for the whole remaining amount.');
    expect(validateRefund({ ...ok, reason: ' x ' }, 5000)).toBe('Give a reason of at least 3 characters.');
  });

  it('reads the real message from an edge function error', async () => {
    expect(await edgeErrorMessage(edgeError('Provider does not support refunds'))).toBe('Provider does not support refunds');
    expect(await edgeErrorMessage({ message: 'network down' })).toBe('network down');
  });
});

describe('payment actions', () => {
  beforeEach(() => vi.resetModules());

  const paymentRow: MockHandler = (req) =>
    req.table === 'payments'
      ? { data: { amount: 50000, payment_type: 'charge', provider_status: 'succeeded' }, error: null }
      : { data: null, error: null };
  const refunds: MockRpcHandler = (name) =>
    name === 'admin_payment_refunds' ? { data: [{ amount: 20000, status: 'succeeded' }], error: null } : { data: null, error: null };

  it('sends a refund through payment-refund with the idempotency key', async () => {
    const c = client(paymentRow, refunds, () => ({ data: { data: { status: 'processing' } }, error: null }));
    const { refundPaymentAction } = await import('@/app/(console)/payments/actions');
    const url = await run(refundPaymentAction, {
      payment_id: PAYMENT,
      idempotency_key: 'refund-abc12345',
      amount: '15000',
      refund_type: 'partial',
      reason: 'Damaged item',
    });
    expect(c.functionCalls).toEqual([
      {
        name: 'payment-refund',
        body: { payment_id: PAYMENT, amount: 15000, reason: 'Damaged item', refund_type: 'partial' },
        headers: { 'x-idempotency-key': 'refund-abc12345' },
      },
    ]);
    expect(url).toContain(`/payments/${PAYMENT}?ok=Refund accepted by the provider and processing`);
  });

  it('refuses to refund more than remains, without calling the function', async () => {
    const c = client(paymentRow, refunds);
    const { refundPaymentAction } = await import('@/app/(console)/payments/actions');
    const url = await run(refundPaymentAction, {
      payment_id: PAYMENT,
      idempotency_key: 'refund-abc12345',
      amount: '40000',
      refund_type: 'partial',
      reason: 'Damaged item',
    });
    expect(c.functionCalls).toEqual([]);
    expect(url).toBe(`/payments/${PAYMENT}?error=At most 30000 can still be refunded.`);
  });

  it('shows the provider reason when the refund fails', async () => {
    client(paymentRow, refunds, () => ({ data: null, error: edgeError('Provider rejected the refund') as never }));
    const { refundPaymentAction } = await import('@/app/(console)/payments/actions');
    const url = await run(refundPaymentAction, {
      payment_id: PAYMENT,
      idempotency_key: 'refund-abc12345',
      amount: '1000',
      refund_type: 'partial',
      reason: 'Damaged item',
    });
    expect(url).toBe(`/payments/${PAYMENT}?error=Refund not sent: Provider rejected the refund`);
  });

  it('rejects a missing idempotency key', async () => {
    const c = client(paymentRow, refunds);
    const { refundPaymentAction } = await import('@/app/(console)/payments/actions');
    const url = await run(refundPaymentAction, { payment_id: PAYMENT, amount: '10', refund_type: 'partial', reason: 'abc' });
    expect(c.functionCalls).toEqual([]);
    expect(url).toContain('The form expired');
  });

  it('completes a processing refund with its reference', async () => {
    const c = client();
    const { completeRefundAction } = await import('@/app/(console)/payments/actions');
    const url = await run(completeRefundAction, { payment_id: PAYMENT, refund_id: REFUND, reference: 'MPESA-QX12' });
    expect(c.rpcCalls).toEqual([{ name: 'admin_complete_refund', args: { p_refund_id: REFUND, p_reference: 'MPESA-QX12' } }]);
    expect(url).toBe(`/payments/${PAYMENT}?ok=Refund marked as paid.`);
  });

  it('cancels a processing refund with a reason', async () => {
    const c = client();
    const { failRefundAction } = await import('@/app/(console)/payments/actions');
    const url = await run(failRefundAction, { payment_id: PAYMENT, refund_id: REFUND, reason: 'Customer number invalid' });
    expect(c.rpcCalls[0]).toEqual({
      name: 'admin_fail_refund',
      args: { p_refund_id: REFUND, p_reason: 'Customer number invalid' },
    });
    expect(url).toContain('Refund cancelled');
  });
});

describe('payout actions', () => {
  beforeEach(() => vi.resetModules());

  it('builds a batch with an inclusive end date', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-23T10:00:00Z'));
    try {
      const c = client(undefined, () => ({ data: BATCH, error: null }));
      const { createPayoutBatchAction } = await import('@/app/(console)/payouts/actions');
      const url = await run(createPayoutBatchAction, {
        country_id: COUNTRY,
        period_start: '2026-11-16',
        period_end: '2026-11-22',
      });
      expect(c.rpcCalls[0]).toEqual({
        name: 'create_payout_batch',
        args: {
          p_country_id: COUNTRY,
          p_period_start: '2026-11-16T00:00:00.000Z',
          p_period_end: '2026-11-23T00:00:00.000Z',
        },
      });
      expect(url).toBe(`/payouts/${BATCH}?ok=Batch created. Review the payouts, then pay them.`);
    } finally {
      vi.useRealTimers();
    }
  });

  it('refuses a period that ends in the future', async () => {
    const c = client();
    const { createPayoutBatchAction } = await import('@/app/(console)/payouts/actions');
    const url = await run(createPayoutBatchAction, {
      country_id: COUNTRY,
      period_start: '2099-01-01',
      period_end: '2099-01-07',
    });
    expect(c.rpcCalls).toEqual([]);
    expect(url).toBe('/payouts?error=A payout period cannot end in the future.');
  });

  it('explains a duplicate batch', async () => {
    client(undefined, () => ({ data: null, error: { message: 'duplicate key value violates unique constraint "payout_batches_country_period_key"' } }));
    const { createPayoutBatchAction } = await import('@/app/(console)/payouts/actions');
    const url = await run(createPayoutBatchAction, { country_id: COUNTRY, period_start: '2026-01-01', period_end: '2026-01-07' });
    expect(url).toBe('/payouts?error=A batch for this country and period already exists.');
  });

  it('pays one payout through payout-execute', async () => {
    const c = client();
    const { payPayoutAction } = await import('@/app/(console)/payouts/actions');
    const url = await run(payPayoutAction, { batch_id: BATCH, payout_id: PAYOUT, idempotency_key: 'payout-abc12345' });
    expect(c.functionCalls).toEqual([
      { name: 'payout-execute', body: { payout_id: PAYOUT }, headers: { 'x-idempotency-key': 'payout-abc12345' } },
    ]);
    expect(url).toBe(`/payouts/${BATCH}?ok=Payout sent.`);
  });

  it('pays all pending payouts with one key each and reports failures', async () => {
    const c = client(
      () => ({ data: [{ id: PAYOUT }, { id: PAYOUT_2 }], error: null }),
      undefined,
      (call) =>
        (call.body as { payout_id: string }).payout_id === PAYOUT_2
          ? { data: null, error: edgeError('Driver has no payout phone number') as never }
          : { data: {}, error: null },
    );
    const { payAllPendingAction } = await import('@/app/(console)/payouts/actions');
    const url = await run(payAllPendingAction, { batch_id: BATCH, idempotency_key: 'batch-abc12345' });
    expect(c.functionCalls.map((f) => f.headers['x-idempotency-key'])).toEqual([
      `batch-abc12345:${PAYOUT.slice(0, 8)}`,
      `batch-abc12345:${PAYOUT_2.slice(0, 8)}`,
    ]);
    const query = c.requests.find((r) => r.table === 'payouts');
    expect(query?.filters).toEqual(
      expect.arrayContaining([
        { column: 'batch_id', operator: 'eq', value: BATCH },
        { column: 'status', operator: 'eq', value: 'pending' },
      ]),
    );
    expect(url).toBe(
      `/payouts/${BATCH}?error=Sent 1, 1 failed. First error: Driver has no payout phone number. Failed payouts can be retried.`,
    );
  });

  it('holds, releases and retries payouts through the database', async () => {
    const c = client();
    const { holdPayoutAction, releasePayoutAction, retryPayoutAction } = await import('@/app/(console)/payouts/actions');
    expect(await run(holdPayoutAction, { batch_id: BATCH, payout_id: PAYOUT, reason: 'Fraud review' })).toBe(
      `/payouts/${BATCH}?ok=Payout held.`,
    );
    await run(releasePayoutAction, { batch_id: BATCH, payout_id: PAYOUT });
    await run(retryPayoutAction, { batch_id: BATCH, payout_id: PAYOUT });
    expect(c.rpcCalls).toEqual([
      { name: 'admin_hold_payout', args: { p_payout_id: PAYOUT, p_reason: 'Fraud review' } },
      { name: 'admin_release_payout', args: { p_payout_id: PAYOUT } },
      { name: 'admin_retry_payout', args: { p_payout_id: PAYOUT } },
    ]);
  });

  it('requires a reason to hold', async () => {
    const c = client();
    const { holdPayoutAction } = await import('@/app/(console)/payouts/actions');
    const url = await run(holdPayoutAction, { batch_id: BATCH, payout_id: PAYOUT, reason: '' });
    expect(c.rpcCalls).toEqual([]);
    expect(url).toBe(`/payouts/${BATCH}?error=Give a reason for holding this payout.`);
  });
});
