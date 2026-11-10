// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { handle } from '../maps-route/handler.ts';
import type { GoogleMapsClient } from '../_shared/providers/google_maps.ts';
import { ProviderError } from '../_shared/errors.ts';

const body = {
  origin: { lat: -6.7924, lng: 39.2083 },
  destination: { lat: -6.7610, lng: 39.2760 },
  mode: 'driving',
};

const encodedPolyline = 'a~iF~Nh|@';

Deno.test('maps-route returns distance, duration and polyline geometry', async () => {
  const maps = {
    calculateRoute: async () => ({
      distance_km: 5.6,
      duration_min: 14.0,
      encoded_polyline: encodedPolyline,
      route_label: 'DEFAULT_ROUTE',
      traffic_aware: true,
    }),
  } as unknown as GoogleMapsClient;

  const handler = createHandler(
    'maps-route',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), maps }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-route', { body }),
  );
  const payload = await response.json();

  assertEquals(response.status, 200);
  assertEquals(payload.data, {
    distance_km: 5.6,
    duration_min: 14.0,
    encoded_polyline: encodedPolyline,
    route_label: 'DEFAULT_ROUTE',
    traffic_aware: true,
    cached: false,
  });
});

Deno.test('maps-route surfaces provider errors as failures', async () => {
  const maps = {
    calculateRoute: async () => {
      throw new ProviderError(
        'google_maps',
        'Routes API returned an empty polyline',
      );
    },
  } as unknown as GoogleMapsClient;

  const handler = createHandler(
    'maps-route',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), maps }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-route', { body }),
  );
  const payload = await response.json();

  assertEquals(response.status, 502);
  assertEquals(payload.error.code, 'provider_error');
});

Deno.test('maps-route rejects a body without coordinates', async () => {
  const handler = createHandler(
    'maps-route',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps() }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-route', {
      body: { origin: { lat: 'x' } },
    }),
  );
  const payload = await response.json();

  assertEquals(response.status, 422);
  assertEquals(payload.error.code, 'validation_error');
});

Deno.test('maps-route requires a bearer token', async () => {
  const handler = createHandler(
    'maps-route',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps() }),
  );
  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-route', { body, token: null }),
  );
  const payload = await response.json();

  assertEquals(response.status, 401);
  assertEquals(payload.error.code, 'unauthorized');
});
