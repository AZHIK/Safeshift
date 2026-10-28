// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../maps-distance/handler.ts';
import type { GoogleMapsClient } from '../_shared/providers/google_maps.ts';

const body = {
  origins: [{ lat: -6.7924, lng: 39.2083 }],
  destinations: [{ lat: -6.7468, lng: 39.2762 }],
  mode: 'driving',
};

Deno.test('maps-distance returns a fresh provider result and writes the cache', async () => {
  let upsertPayload: unknown = null;
  const service = createSupabaseMock({
    tables: {
      distance_cache: {
        select: () => ({ data: null, error: null }),
        upsert: (context) => {
          upsertPayload = context.payload;
          return { data: null, error: null };
        },
      },
    },
  });
  const maps = {
    calculateDistance: async () => ({ distance_km: 14.5, duration_min: 31.2 }),
  } as unknown as GoogleMapsClient;

  const handler = createHandler(
    'maps-distance',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), service, maps }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-distance', { body }),
  );
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.data, { distance_km: 14.5, duration_min: 31.2, cached: false });
  assertEquals((upsertPayload as { distance_km: number }).distance_km, 14.5);
});

Deno.test('maps-distance returns a cache hit without calling Google', async () => {
  let called = false;
  const service = createSupabaseMock({
    tables: {
      distance_cache: {
        select: () => ({ data: { distance_km: '9.25', duration_min: '20.5' }, error: null }),
      },
    },
  });
  const maps = {
    calculateDistance: async () => {
      called = true;
      return { distance_km: 1, duration_min: 1 };
    },
  } as unknown as GoogleMapsClient;

  const handler = createHandler(
    'maps-distance',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), service, maps }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-distance', { body }),
  );
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.data, { distance_km: 9.25, duration_min: 20.5, cached: true });
  assertEquals(called, false);
});
