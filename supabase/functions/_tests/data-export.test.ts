import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../data-export/handler.ts';

const profileId = '00000000-0000-4000-8000-000000000001';
const requestId = '55555555-5555-4555-8555-555555555555';

Deno.test('data-export builds a ZIP and marks the request completed', async () => {
  const captured: { path: string | null; updated: Record<string, unknown> | null } = {
    path: null,
    updated: null,
  };
  const service = createSupabaseMock({
    tables: {
      profiles: {
        select: () => ({
          data: { id: profileId, full_name: 'Test Customer', email: 'customer@example.test' },
          error: null,
        }),
      },
      data_subject_requests: {
        select: () => ({
          data: {
            id: requestId,
            requester_profile_id: profileId,
            request_type: 'export',
            status: 'in_progress',
          },
          error: null,
        }),
        update: (context) => {
          captured.updated = context.payload as Record<string, unknown>;
          return { data: null, error: null };
        },
      },
    },
    storage: {
      upload(bucket, path) {
        assertEquals(bucket, 'data-exports');
        captured.path = path;
        return { data: { path }, error: null };
      },
    },
  });

  const handler = createHandler('data-export', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      userClient: () => service,
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/data-export', {
      body: { request_id: requestId },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.error, null);
  assertEquals(body.data.request_id, requestId);
  assertEquals(body.data.download_url.includes('/data-exports/'), true);
  assertEquals(captured.path?.startsWith(`${profileId}/export-${requestId}-`), true);
  assertEquals(captured.path?.endsWith('.zip'), true);
  assertEquals(captured.updated?.status, 'completed');
  assertEquals(captured.updated?.delivered_file_path, captured.path);
});

Deno.test('data-export surfaces a domain query failure instead of exporting empty data', async () => {
  const service = createSupabaseMock({
    tables: {
      profiles: { select: () => ({ data: { id: profileId }, error: null }) },
      data_subject_requests: {
        select: () => ({
          data: {
            id: requestId,
            requester_profile_id: profileId,
            request_type: 'export',
            status: 'in_progress',
          },
          error: null,
        }),
        update: () => ({ data: null, error: null }),
      },
      jobs: {
        select: () => ({
          data: null,
          error: { code: '42703', message: 'column does not exist' },
        }),
      },
    },
  });

  const handler = createHandler('data-export', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      userClient: () => service,
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/data-export', {
      body: { request_id: requestId },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error.code, 'internal_error');
});

Deno.test('data-export allows a customer to self-export by profile id', async () => {
  const service = createSupabaseMock({
    tables: {
      profiles: {
        select: () => ({
          data: { id: profileId, full_name: 'Test Customer' },
          error: null,
        }),
      },
      data_subject_requests: {
        insert: () => ({
          data: {
            id: requestId,
            requester_profile_id: profileId,
            request_type: 'export',
            status: 'in_progress',
          },
          error: null,
        }),
        update: () => ({ data: null, error: null }),
      },
    },
  });

  const handler = createHandler('data-export', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      userClient: () => service,
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/data-export', {
      body: { profile_id: profileId },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.request_id, requestId);
  assertEquals(body.error, null);
});
