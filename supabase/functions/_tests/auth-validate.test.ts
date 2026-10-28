// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../auth-validate/handler.ts';

Deno.test('auth-validate rejects an invalid JWT', async () => {
  const handler = createHandler(
    'auth-validate',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps({ verifyToken: async () => null }) }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/auth-validate', { method: 'GET' }),
  );
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error.code, 'unauthorized');
});

Deno.test('auth-validate returns profile claims and hydrated permissions', async () => {
  const client = createSupabaseMock({
    rpc(name) {
      if (name === 'current_permissions') {
        return { data: ['manage_notifications', 'process_refunds'], error: null };
      }
      return { data: null, error: null };
    },
  });
  const handler = createHandler(
    'auth-validate',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), userClient: () => client }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/auth-validate', { method: 'GET' }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.role, 'customer');
  assertEquals(body.data.isActive, true);
  assertEquals(body.data.permissions, ['manage_notifications', 'process_refunds']);
});

Deno.test('auth-validate surfaces a permission RPC failure', async () => {
  const client = createSupabaseMock({
    rpc(name) {
      if (name === 'current_permissions') {
        return { data: null, error: { code: 'XX000', message: 'permission lookup failed' } };
      }
      return { data: null, error: null };
    },
  });
  const handler = createHandler(
    'auth-validate',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), userClient: () => client }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/auth-validate', { method: 'GET' }),
  );
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error.code, 'internal_error');
});
