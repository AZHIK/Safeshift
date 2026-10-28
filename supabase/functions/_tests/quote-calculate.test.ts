// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../quote-calculate/handler.ts';

const vehicleTypeId = '11111111-1111-4111-8111-111111111111';

function request(token?: string | null): Request {
  return jsonRequest('http://localhost/functions/v1/quote-calculate', {
    token,
    body: {
      pickup: { lat: -6.7924, lng: 39.2083, address: 'Kariakoo, Dar es Salaam' },
      destination: { lat: -6.7468, lng: 39.2762, address: 'Mbezi Beach, Dar es Salaam' },
      vehicle_type_id: vehicleTypeId,
      stop_count: 2,
    },
  });
}

Deno.test('quote-calculate rejects a missing bearer token', async () => {
  const handler = createHandler('quote-calculate', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps({ verifyToken: async () => null }),
      mapsDistance: async () => ({ distance_km: 1, duration_min: 1 }),
    }));

  const response = await handler(request(null));
  const body = await response.json();

  assertEquals(response.status, 401);
  assertEquals(body.data, null);
  assertEquals(body.error.code, 'unauthorized');
});

Deno.test('quote-calculate calls the Phase 4 RPC with provider distance', async () => {
  const captured: { args: Record<string, unknown> | null } = { args: null };
  const client = createSupabaseMock({
    rpc(name, args) {
      if (name === 'quote_calculate_and_persist') {
        captured.args = args;
        return { data: '22222222-2222-4222-8222-222222222222', error: null };
      }
      return { data: null, error: null };
    },
    tables: {
      quotes: {
        select: () => ({
          data: {
            pricing_breakdown_snapshot: { total: 12500, currency: 'TZS' },
            expires_at: '2026-10-29T00:00:00.000Z',
          },
          error: null,
        }),
      },
    },
  });

  const handler = createHandler('quote-calculate', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      userClient: () => client,
      mapsDistance: async () => ({ distance_km: 14.5, duration_min: 31.2 }),
    }));

  const response = await handler(request());
  const body = await response.json();

  assertEquals(response.status, 201);
  assertEquals(body.error, null);
  assertEquals(body.data.quote_id, '22222222-2222-4222-8222-222222222222');
  assertEquals(body.data.breakdown.total, 12500);
  assertEquals(body.data.expires_at, '2026-10-29T00:00:00.000Z');
  assertEquals(captured.args?.p_distance_km, 14.5);
  assertEquals(captured.args?.p_duration_min, 31.2);
  assertEquals(
    captured.args?.p_pickup_location,
    'SRID=4326;POINT(39.2083 -6.7924)',
  );
});

Deno.test('quote-calculate uses a fresh distance cache hit without a provider client', async () => {
  const captured: { args: Record<string, unknown> | null } = { args: null };
  const client = createSupabaseMock({
    rpc(name, args) {
      if (name === 'quote_calculate_and_persist') {
        captured.args = args;
        return { data: '33333333-3333-4333-8333-333333333333', error: null };
      }
      return { data: null, error: null };
    },
    tables: {
      distance_cache: {
        select: () => ({ data: { distance_km: 9.5, duration_min: 20 }, error: null }),
      },
      quotes: {
        select: () => ({
          data: {
            pricing_breakdown_snapshot: { total: 9000, currency: 'TZS' },
            expires_at: '2026-10-29T00:00:00.000Z',
          },
          error: null,
        }),
      },
    },
  });

  const handler = createHandler('quote-calculate', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service: client,
      userClient: () => client,
    }));

  const response = await handler(request());
  const body = await response.json();

  assertEquals(response.status, 201);
  assertEquals(body.data.quote_id, '33333333-3333-4333-8333-333333333333');
  assertEquals(captured.args?.p_distance_km, 9.5);
  assertEquals(captured.args?.p_duration_min, 20);
});
