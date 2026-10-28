// deno-lint-ignore-file require-await
import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.14';
import { ProviderError } from '../_shared/errors.ts';
import { requestJson } from '../_shared/providers/base.ts';

Deno.test('provider calls retry network failures and then succeed', async () => {
  let calls = 0;
  const fetchImpl = (async () => {
    calls += 1;
    if (calls < 3) throw new TypeError('fetch failed');
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  }) as typeof fetch;

  const result = await requestJson<{ ok: boolean }>(
    'test-provider',
    'https://provider.test/v1/resource',
    { method: 'GET' },
    {
      fetchImpl,
      sleep: async () => {},
      requestId: 'req-retry',
    },
  );

  assertEquals(calls, 3);
  assertEquals(result.data, { ok: true });
});

Deno.test('provider 4xx responses are not retried', async () => {
  let calls = 0;
  const fetchImpl = (async () => {
    calls += 1;
    return new Response(JSON.stringify({ error: 'bad request' }), { status: 400 });
  }) as typeof fetch;

  await assertRejects(
    () =>
      requestJson(
        'test-provider',
        'https://provider.test/v1/resource',
        { method: 'POST' },
        { fetchImpl, sleep: async () => {}, requestId: 'req-4xx' },
      ),
    ProviderError,
  );

  assertEquals(calls, 1);
});
