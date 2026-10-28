// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { rawRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../payment-selcom-webhook/handler.ts';
import { insertWebhook } from '../_shared/webhooks.ts';

const provider = { id: '44444444-4444-4444-8444-444444444444', webhook_secret_reference: null };
const rawBody = JSON.stringify({
  event_type: 'payment.updated',
  event_id: 'event-1',
  data: { order_id: 'provider-ref-1', status: 'success', amount: 12500 },
});

Deno.test('Selcom webhook rejects an invalid signature with 401', async () => {
  let inserted = false;
  const handler = createHandler('payment-selcom-webhook', (req, ctx) =>
    handle(req, ctx, {
      service: createSupabaseMock(),
      provider,
      secret: 'webhook-secret',
      verify: async () => false,
      insertEvent: async () => {
        inserted = true;
        return { id: 1, duplicate: false };
      },
    }));

  const response = await handler(
    rawRequest('http://localhost/functions/v1/payment-selcom-webhook', rawBody, {
      'x-selcom-signature': 'wrong',
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error.code, 'unauthorized');
  assertEquals(inserted, false);
});

Deno.test('Selcom webhook stores and reconciles a valid success event', async () => {
  const completed: Array<{ paymentId: string; reference: string; status: string }> = [];
  const marked: Array<{ id: number; status: string }> = [];
  const handler = createHandler('payment-selcom-webhook', (req, ctx) =>
    handle(req, ctx, {
      service: createSupabaseMock(),
      provider,
      secret: 'webhook-secret',
      verify: async () => true,
      insertEvent: async () => ({ id: 7, duplicate: false }),
      findPayment: async () => ({ id: 'payment-1', job_id: 'job-1', provider_status: 'pending' }),
      markEvent: async (_service, id, status) => {
        marked.push({ id, status });
      },
      completePayment: async (paymentId, reference, status) => {
        completed.push({ paymentId, reference, status });
      },
    }));

  const response = await handler(
    rawRequest('http://localhost/functions/v1/payment-selcom-webhook', rawBody, {
      'x-selcom-signature': 'valid',
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data, { payment_id: 'payment-1', status: 'succeeded' });
  assertEquals(completed, [
    { paymentId: 'payment-1', reference: 'provider-ref-1', status: 'succeeded' },
  ]);
  assertEquals(marked, [{ id: 7, status: 'processed' }]);
});

Deno.test('Selcom webhook acknowledges duplicate events without reprocessing', async () => {
  let completed = false;
  const handler = createHandler('payment-selcom-webhook', (req, ctx) =>
    handle(req, ctx, {
      service: createSupabaseMock(),
      provider,
      secret: 'webhook-secret',
      verify: async () => true,
      insertEvent: async () => ({ id: 0, duplicate: true }),
      completePayment: async () => {
        completed = true;
      },
    }));

  const response = await handler(
    rawRequest('http://localhost/functions/v1/payment-selcom-webhook', rawBody, {
      'x-selcom-signature': 'valid',
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data, { duplicate: true });
  assertEquals(completed, false);
});

Deno.test('insertWebhook uses the atomic dedupe RPC and returns the new row id', async () => {
  let rpcName = '';
  let rpcArgs: Record<string, unknown> = {};
  const service = createSupabaseMock({
    rpc(name, args) {
      rpcName = name;
      rpcArgs = args;
      return { data: [{ webhook_id: 9, duplicate: false }], error: null };
    },
  });

  const result = await insertWebhook(service, {
    providerId: provider.id,
    eventType: 'payment.updated',
    eventId: 'event-1',
    providerReference: 'provider-ref-1',
    payload: { data: { status: 'success' } },
    signatureHeader: 'signature',
  });

  assertEquals(result, { id: 9, duplicate: false });
  assertEquals(rpcName, 'record_payment_webhook');
  assertEquals(rpcArgs.p_event_id, 'event-1');
  assertEquals(rpcArgs.p_signature_header, 'signature');
});

Deno.test('insertWebhook reports a duplicate from the dedupe RPC', async () => {
  const service = createSupabaseMock({
    rpc: () => ({ data: [{ webhook_id: null, duplicate: true }], error: null }),
  });

  const result = await insertWebhook(service, {
    providerId: provider.id,
    eventType: 'payment.updated',
    eventId: 'event-1',
    providerReference: null,
    payload: { data: { status: 'success' } },
    signatureHeader: null,
  });

  assertEquals(result, { id: 0, duplicate: true });
});
