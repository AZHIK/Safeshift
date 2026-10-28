import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../health/handler.ts';

function request(): Request {
  return new Request('http://localhost/functions/v1/health', { method: 'GET' });
}

Deno.test('health reports ok when the database and Vault are reachable', async () => {
  const service = createSupabaseMock({
    tables: {
      countries: { select: () => ({ data: null, error: null }) },
    },
    rpc: () => ({ data: 'ok', error: null }),
  });
  const handler = createHandler('health', (req, ctx) => handle(req, ctx, { service }));

  const response = await handler(request());
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.status, 'ok');
  assertEquals(body.data.checks.db, true);
  assertEquals(body.data.checks.vault, true);
});

Deno.test('health returns 503 when Vault is unavailable', async () => {
  const service = createSupabaseMock({
    tables: {
      countries: { select: () => ({ data: null, error: null }) },
    },
    rpc: () => ({ data: null, error: { message: 'vault unavailable' } }),
  });
  const handler = createHandler('health', (req, ctx) => handle(req, ctx, { service }));

  const response = await handler(request());
  const body = await response.json();

  assertEquals(response.status, 503);
  assertEquals(body.data.status, 'degraded');
  assertEquals(body.data.checks.vault, false);
});
