import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { getIdempotencyKey, SupabaseIdempotencyStore } from '../_shared/idempotency.ts';
import { createSupabaseMock } from './mocks.ts';

Deno.test('idempotency keys are scoped and stored with the response', async () => {
  const captured: { value: Record<string, unknown> | null } = { value: null };
  const client = createSupabaseMock({
    tables: {
      idempotency_keys: {
        select: () => ({
          data: { response: { payment_id: 'existing-payment' } },
          error: null,
        }),
        upsert: (context) => {
          captured.value = context.payload as Record<string, unknown>;
          return { data: null, error: null };
        },
      },
    },
  });
  const store = new SupabaseIdempotencyStore(client);

  const cached = await store.get('key-1', 'payment-selcom-initiate');
  assertEquals(cached, { response: { payment_id: 'existing-payment' } });

  await store.put(
    'key-1',
    'payment-selcom-initiate',
    { payment_id: 'new-payment' },
    'request-hash',
  );
  assertEquals(captured.value?.key, 'key-1');
  assertEquals(captured.value?.scope, 'payment-selcom-initiate');
  assertEquals(captured.value?.request_hash, 'request-hash');
  assertEquals(captured.value?.response, { payment_id: 'new-payment' });
});

Deno.test('idempotency header parsing trims and rejects blank values', () => {
  const withKey = new Request('http://localhost', {
    headers: { 'x-idempotency-key': '  key-1  ' },
  });
  const blank = new Request('http://localhost', {
    headers: { 'x-idempotency-key': '   ' },
  });
  const missing = new Request('http://localhost');

  assertEquals(getIdempotencyKey(withKey), 'key-1');
  assertEquals(getIdempotencyKey(blank), null);
  assertEquals(getIdempotencyKey(missing), null);
});
