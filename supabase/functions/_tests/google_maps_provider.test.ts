import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.14';
import { GoogleMapsClient } from '../_shared/providers/google_maps.ts';

Deno.test('GoogleMapsClient uses Routes API computeRouteMatrix', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;

  const fetchImpl: typeof fetch = async (input, init) => {
    capturedUrl = String(input);
    capturedInit = init;
    return new Response(
      JSON.stringify([
        {
          originIndex: 0,
          destinationIndex: 0,
          status: {},
          condition: 'ROUTE_EXISTS',
          distanceMeters: 12345,
          duration: '330s',
        },
      ]),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };

  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    routesBaseUrl: 'https://routes.example',
    fetchImpl,
  });

  const result = await client.calculateDistance(
    [{ lat: -6.818, lng: 39.27 }],
    [{ lat: -6.775, lng: 39.225 }],
    'driving',
  );

  assertEquals(result, { distance_km: 12.35, duration_min: 5.5 });
  assertEquals(capturedUrl, 'https://routes.example/distanceMatrix/v2:computeRouteMatrix');
  assertEquals(capturedInit?.method, 'POST');

  const headers = new Headers(capturedInit?.headers);
  assertEquals(headers.get('X-Goog-Api-Key'), 'test-key');
  assertEquals(
    headers.get('X-Goog-FieldMask'),
    'originIndex,destinationIndex,duration,distanceMeters,status,condition',
  );

  const body = JSON.parse(String(capturedInit?.body));
  assertEquals(body.travelMode, 'DRIVE');
  assertEquals(body.routingPreference, 'TRAFFIC_AWARE');
  assertEquals(body.origins[0].waypoint.location.latLng, {
    latitude: -6.818,
    longitude: 39.27,
  });
});

Deno.test('GoogleMapsClient rejects an element without a route', async () => {
  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    routesBaseUrl: 'https://routes.example',
    fetchImpl: async () =>
      new Response(
        JSON.stringify([
          {
            originIndex: 0,
            destinationIndex: 0,
            status: {},
            condition: 'ROUTE_NOT_FOUND',
          },
        ]),
        { status: 200, headers: { 'content-type': 'application/json' } },
      ),
  });

  await assertRejects(
    () =>
      client.calculateDistance(
        [{ lat: -6.818, lng: 39.27 }],
        [{ lat: -6.775, lng: 39.225 }],
        'driving',
      ),
    Error,
    'ROUTE_NOT_FOUND',
  );
});
