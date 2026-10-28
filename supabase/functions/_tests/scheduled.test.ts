// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle as dailyMetrics } from '../scheduled-daily-metrics/handler.ts';
import { handle as retention } from '../scheduled-retention/handler.ts';

Deno.test('scheduled functions reject a missing cron secret', async () => {
  const handler = createHandler('scheduled-daily-metrics', (req, ctx) =>
    dailyMetrics(req, ctx, {
      auth: fakeAuthDeps({ getCronSecret: async () => 'expected-secret' }),
      service: createSupabaseMock(),
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/scheduled-daily-metrics', { method: 'POST' }),
  );
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.error.code, 'unauthorized');
});

Deno.test('scheduled-daily-metrics computes all four metric families', async () => {
  const service = createSupabaseMock({
    rpc(name) {
      const counts: Record<string, number> = {
        compute_daily_metrics: 4,
        compute_zone_metrics: 3,
        compute_driver_metrics: 2,
        compute_customer_metrics: 1,
      };
      return { data: counts[name] ?? 0, error: null };
    },
  });
  const handler = createHandler(
    'scheduled-daily-metrics',
    (req, ctx) => dailyMetrics(req, ctx, { auth: fakeAuthDeps(), service }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/scheduled-daily-metrics', {
      method: 'POST',
      headers: { 'x-cron-secret': 'test-cron-secret' },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.daily_metrics_rows, 4);
  assertEquals(body.data.zone_metrics_rows, 3);
  assertEquals(body.data.driver_metrics_rows, 2);
  assertEquals(body.data.customer_metrics_rows, 1);
});

Deno.test('scheduled-retention aggregates policy and cleanup counts', async () => {
  const removed: string[] = [];
  const service = createSupabaseMock({
    rpc(name) {
      if (name === 'apply_retention_policies') {
        return {
          data: [
            { table_name: 'driver_locations', rows_deleted: 10 },
            { table_name: 'notification_log', rows_deleted: '3' },
          ],
          error: null,
        };
      }
      if (name === 'cleanup_idempotency_keys') return { data: 2, error: null };
      if (name === 'cleanup_expired_data_exports') return { data: 1, error: null };
      if (name === 'cleanup_payment_webhook_events') return { data: 4, error: null };
      return { data: null, error: null };
    },
    storage: {
      list(bucket, prefix) {
        assertEquals(bucket, 'data-exports');
        if (prefix === '') {
          return {
            data: [{ name: 'profile-1', id: null, created_at: null }],
            error: null,
          };
        }
        return {
          data: [
            {
              name: 'old-export.zip',
              id: '1',
              created_at: '2026-01-01T00:00:00.000Z',
            },
            {
              name: 'fresh-export.zip',
              id: '2',
              created_at: '2026-10-27T00:00:00.000Z',
            },
          ],
          error: null,
        };
      },
      remove(bucket, paths) {
        assertEquals(bucket, 'data-exports');
        removed.push(...paths);
        return { data: paths.map((name) => ({ name })), error: null };
      },
    },
  });
  const handler = createHandler(
    'scheduled-retention',
    (req, ctx) =>
      retention(req, ctx, {
        auth: fakeAuthDeps(),
        service,
        now: () => new Date('2026-10-28T00:00:00.000Z'),
      }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/scheduled-retention', {
      method: 'POST',
      headers: { 'x-cron-secret': 'test-cron-secret' },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.policies_applied, 2);
  assertEquals(body.data.total_rows_deleted, 13);
  assertEquals(body.data.idempotency_keys_deleted, 2);
  assertEquals(body.data.expired_exports_deleted, 1);
  assertEquals(body.data.expired_export_records_cleared, 1);
  assertEquals(body.data.webhook_events_deleted, 4);
  assertEquals(removed, ['profile-1/old-export.zip']);
});
