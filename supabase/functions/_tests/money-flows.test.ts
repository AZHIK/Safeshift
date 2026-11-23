// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import type { IdempotencyRecord, IdempotencyStore } from '../_shared/idempotency.ts';
import { handle as refundHandle } from '../payment-refund/handler.ts';
import { handle as payoutHandle } from '../payout-execute/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock, type QueryContext } from './mocks.ts';

const paymentId = '11111111-1111-4111-8111-111111111111';
const refundPaymentId = '22222222-2222-4222-8222-222222222222';
const refundId = '33333333-3333-4333-8333-333333333333';
const payoutId = '44444444-4444-4444-8444-444444444444';

class MemoryStore implements IdempotencyStore {
  readonly records = new Map<string, IdempotencyRecord>();
  async get(key: string, scope: string) {
    return this.records.get(`${scope}:${key}`) ?? null;
  }
  async put(key: string, scope: string, response: unknown, requestHash?: string) {
    this.records.set(
      `${scope}:${key}`,
      { response, request_hash: requestHash } as IdempotencyRecord,
    );
  }
}

function refundService(
  updates: Record<string, unknown>[],
  charge: Record<string, unknown> = {},
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => { data: unknown; error: { message: string } | null } = () => ({
    data: null,
    error: null,
  }),
) {
  return createSupabaseMock({
    rpc,
    tables: {
      payments: {
        select: () => ({
          data: {
            id: paymentId,
            provider_id: 'p1',
            provider_reference: 'SEL-123',
            amount: 50000,
            currency_code: 'TZS',
            payment_type: 'charge',
            provider_status: 'succeeded',
            ...charge,
          },
          error: null,
        }),
      },
      payment_providers: {
        select: () => ({ data: { code: 'selcom', supports_refunds: true }, error: null }),
      },
      refunds: {
        select: () => ({
          data: { id: refundId, provider_reference: null, status: 'requested' },
          error: null,
        }),
        update: (ctx: QueryContext) => {
          updates.push(ctx.payload as Record<string, unknown>);
          // Mirror refunds_status_check on the real table.
          const status = (ctx.payload as { status?: string }).status;
          if (status && !['requested', 'processing', 'succeeded', 'failed'].includes(status)) {
            return {
              data: null,
              error: { message: 'violates check constraint "refunds_status_check"' },
            };
          }
          return { data: null, error: null };
        },
      },
    },
  });
}

function refundRequest(key = 'refund-key-1') {
  return jsonRequest('http://localhost/functions/v1/payment-refund', {
    body: { payment_id: paymentId, amount: 20000, reason: 'Damaged item', refund_type: 'partial' },
    headers: { 'x-idempotency-key': key },
  });
}

function refundHandler(
  service: ReturnType<typeof createSupabaseMock>,
  providerStatus: 'pending' | 'succeeded' | 'failed',
  store = new MemoryStore(),
  calls: unknown[] = [],
) {
  return createHandler('payment-refund', (req, ctx) =>
    refundHandle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      idempotency: store,
      userClient: () =>
        createSupabaseMock({
          rpc: (name, args) => {
            calls.push({ name, args });
            return { data: refundPaymentId, error: null };
          },
        }),
      refundProvider: async () => ({ refund_reference: 'R-1', status: providerStatus }),
    }));
}

Deno.test('payment-refund records an accepted, unsettled refund as processing', async () => {
  const updates: Record<string, unknown>[] = [];
  const calls: unknown[] = [];
  const res = await refundHandler(refundService(updates), 'pending', new MemoryStore(), calls)(
    refundRequest(),
  );
  const body = await res.json();
  assertEquals(res.status, 201);
  assertEquals(body.data.status, 'processing');
  // Stays processing; only the provider reference is recorded.
  assertEquals(updates, [{ provider_reference: 'R-1' }]);
  assertEquals(calls, [
    {
      name: 'payment_refund',
      args: {
        p_payment_id: paymentId,
        p_refund_amount: 20000,
        p_refund_type: 'partial',
        p_reason: 'Damaged item',
      },
    },
  ]);
});

Deno.test('payment-refund completes a settled refund in the database', async () => {
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const service = refundService([], {}, (name, args) => {
    rpcs.push({ name, args });
    return { data: null, error: null };
  });
  const res = await refundHandler(service, 'succeeded')(refundRequest());
  assertEquals(res.status, 201);
  assertEquals((await res.json()).data.status, 'succeeded');
  assertEquals(rpcs, [{
    name: 'complete_refund',
    args: { p_refund_id: refundId, p_provider_reference: 'R-1' },
  }]);
});

Deno.test('payment-refund never reverses a refund the provider accepted', async () => {
  const rpcs: string[] = [];
  const service = refundService([], {}, (name) => {
    rpcs.push(name);
    return name === 'complete_refund'
      ? { data: null, error: { message: 'db down' } }
      : { data: null, error: null };
  });
  const res = await refundHandler(service, 'succeeded')(refundRequest());
  assertEquals(res.status, 500);
  assertEquals(rpcs, ['complete_refund']);
});

Deno.test('payment-refund reverses the booked refund when the provider rejects it', async () => {
  const updates: Record<string, unknown>[] = [];
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const service = refundService(updates, {}, (name, args) => {
    rpcs.push({ name, args });
    return { data: null, error: null };
  });
  const res = await refundHandler(service, 'failed')(refundRequest());
  assertEquals(res.status, 502);
  assertEquals(rpcs, [
    {
      name: 'reverse_failed_refund',
      args: { p_refund_id: refundId, p_reason: 'Provider rejected the refund' },
    },
  ]);
});

Deno.test('payment-refund still marks the refund failed if the reversal errors', async () => {
  const updates: Record<string, unknown>[] = [];
  const service = refundService(updates, {}, () => ({ data: null, error: { message: 'db down' } }));
  const res = await refundHandler(service, 'failed')(refundRequest());
  assertEquals(res.status, 502);
  assertEquals(updates.at(-1), {
    status: 'failed',
    failure_reason: 'Provider rejected the refund',
  });
});

Deno.test('payment-refund replays the stored response for a repeated key', async () => {
  const store = new MemoryStore();
  const calls: unknown[] = [];
  const handler = refundHandler(refundService([]), 'succeeded', store, calls);
  await handler(refundRequest('same-key'));
  const again = await handler(refundRequest('same-key'));
  assertEquals(again.status, 200);
  assertEquals(calls.length, 1);
});

Deno.test('payment-refund refuses anything but a succeeded charge', async () => {
  const res = await refundHandler(refundService([], { provider_status: 'pending' }), 'succeeded')(
    refundRequest(),
  );
  assertEquals(res.status, 422);
});

Deno.test('payment-refund requires an idempotency key', async () => {
  const req = jsonRequest('http://localhost/functions/v1/payment-refund', {
    body: { payment_id: paymentId, amount: 20000, reason: 'Damaged item' },
  });
  const res = await refundHandler(refundService([]), 'succeeded')(req);
  assertEquals(res.status, 422);
});

function payoutService(updates: Record<string, unknown>[], payout: Record<string, unknown> = {}) {
  return createSupabaseMock({
    tables: {
      payouts: {
        select: () => ({
          data: {
            id: payoutId,
            driver_id: 'd1',
            net_amount: 120000,
            currency_code: 'TZS',
            status: 'pending',
            payment_provider_id: 'p1',
            provider_reference: null,
            ...payout,
          },
          error: null,
        }),
        update: (ctx: QueryContext) => {
          updates.push(ctx.payload as Record<string, unknown>);
          return { data: null, error: null };
        },
      },
      payment_providers: { select: () => ({ data: { code: 'selcom' }, error: null }) },
      profiles: { select: () => ({ data: { phone: '+255712345678' }, error: null }) },
    },
  });
}

function payoutHandler(
  service: ReturnType<typeof createSupabaseMock>,
  status: 'pending' | 'succeeded' | 'failed',
  calls: unknown[] = [],
) {
  return createHandler('payout-execute', (req, ctx) =>
    payoutHandle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      idempotency: new MemoryStore(),
      userClient: () =>
        createSupabaseMock({
          rpc: (name, args) => {
            calls.push({ name, args });
            return { data: null, error: null };
          },
        }),
      transfer: async (_code, amount, currency, phone, reference) => {
        calls.push({ transfer: { amount, currency, phone, reference } });
        return { provider_reference: 'T-1', status };
      },
    }));
}

function payoutRequest() {
  return jsonRequest('http://localhost/functions/v1/payout-execute', {
    body: { payout_id: payoutId },
    headers: { 'x-idempotency-key': 'payout-key-1' },
  });
}

Deno.test('payout-execute sends the net amount to the driver and settles the payout', async () => {
  const updates: Record<string, unknown>[] = [];
  const calls: unknown[] = [];
  const res = await payoutHandler(payoutService(updates), 'pending', calls)(payoutRequest());
  assertEquals(res.status, 200);
  assertEquals(calls, [
    {
      transfer: {
        amount: 120000,
        currency: 'TZS',
        phone: '+255712345678',
        reference: `payout:${payoutId}`,
      },
    },
    { name: 'execute_payout', args: { p_payout_id: payoutId } },
  ]);
  assertEquals(updates[0], {
    status: 'processing',
    provider_reference: 'T-1',
    failure_reason: null,
  });
});

Deno.test('payout-execute marks a rejected transfer as failed', async () => {
  const updates: Record<string, unknown>[] = [];
  const res = await payoutHandler(payoutService(updates), 'failed')(payoutRequest());
  assertEquals(res.status, 422);
  assertEquals(updates[0].status, 'failed');
});

Deno.test('payout-execute does not pay a completed payout twice', async () => {
  const calls: unknown[] = [];
  const res = await payoutHandler(
    payoutService([], { status: 'completed', provider_reference: 'T-0' }),
    'succeeded',
    calls,
  )(
    payoutRequest(),
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).data.status, 'completed');
  assertEquals(calls, []);
});

Deno.test('payout-execute refuses a cancelled payout', async () => {
  const res = await payoutHandler(payoutService([], { status: 'cancelled' }), 'succeeded')(
    payoutRequest(),
  );
  assertEquals(res.status, 422);
});

Deno.test('payout-execute refuses a held payout before any transfer', async () => {
  const calls: unknown[] = [];
  const res = await payoutHandler(payoutService([], { status: 'on_hold' }), 'succeeded', calls)(
    payoutRequest(),
  );
  assertEquals(res.status, 422);
  assertEquals(calls, []);
});
