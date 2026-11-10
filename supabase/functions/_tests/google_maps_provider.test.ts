// deno-lint-ignore-file require-await
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

Deno.test('GoogleMapsClient uses Routes API computeRoutes', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;

  const fetchImpl: typeof fetch = async (input, init) => {
    capturedUrl = String(input);
    capturedInit = init;
    return new Response(
      JSON.stringify({
        routes: [
          {
            distanceMeters: 11864,
            duration: '1386s',
            polyline: { encodedPolyline: 'jsmh@qzhnFmB]{C]oGUcAEoAOmDw' },
            routeLabels: ['DEFAULT_ROUTE'],
          },
        ],
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };

  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    routesBaseUrl: 'https://routes.example',
    fetchImpl,
  });

  const result = await client.calculateRoute(
    { lat: -6.7924, lng: 39.2083 },
    { lat: -6.761, lng: 39.276 },
    'driving',
  );

  assertEquals(result, {
    distance_km: 11.86,
    duration_min: 23.1,
    encoded_polyline: 'jsmh@qzhnFmB]{C]oGUcAEoAOmDw',
    route_label: 'DEFAULT_ROUTE',
    traffic_aware: true,
  });

  // Compute Routes is served from /directions/v2. There is no /v1:computeRoutes
  // path: requesting it 404s with an empty body.
  assertEquals(capturedUrl, 'https://routes.example/directions/v2:computeRoutes');
  assertEquals(capturedInit?.method, 'POST');

  const headers = new Headers(capturedInit?.headers);
  assertEquals(headers.get('X-Goog-Api-Key'), 'test-key');
  assertEquals(
    headers.get('X-Goog-FieldMask'),
    'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.routeLabels',
  );

  const body = JSON.parse(String(capturedInit?.body));
  assertEquals(body.travelMode, 'DRIVE');
  assertEquals(body.routingPreference, 'TRAFFIC_AWARE');
  // `PolylineQuality` is an enum. "HIGH" is not a member; the valid spelling
  // is "HIGH_QUALITY". Sending "HIGH" is rejected with INVALID_ARGUMENT.
  assertEquals(body.polylineQuality, 'HIGH_QUALITY');
  assertEquals(body.polylineEncoding, 'ENCODED_POLYLINE');
  assertEquals(body.origin.location.latLng, { latitude: -6.7924, longitude: 39.2083 });
  assertEquals(body.destination.location.latLng, { latitude: -6.761, longitude: 39.276 });
});

Deno.test('GoogleMapsClient never routes through the geocoding base URL', async () => {
  let capturedUrl = '';

  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    baseUrl: 'https://maps.example',
    fetchImpl: async (input) => {
      capturedUrl = String(input);
      return new Response(JSON.stringify({ routes: [] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
  });

  await client.calculateRoute(
    { lat: -6.7924, lng: 39.2083 },
    { lat: -6.761, lng: 39.276 },
    'driving',
  ).catch(() => undefined);

  // The Routes API has its own host. Falling back to `baseUrl` would post the
  // Compute Routes request to the Geocoding/Places host.
  assertEquals(capturedUrl, 'https://routes.googleapis.com/directions/v2:computeRoutes');
});

Deno.test('requestJson surfaces the provider error envelope', async () => {
  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    routesBaseUrl: 'https://routes.example',
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: {
            code: 400,
            message: "Invalid value at 'polyline_quality' (\"HIGH\")",
            status: 'INVALID_ARGUMENT',
          },
        }),
        { status: 400, headers: { 'content-type': 'application/json' } },
      ),
  });

  const error = await client
    .calculateRoute(
      { lat: -6.7924, lng: 39.2083 },
      { lat: -6.761, lng: 39.276 },
      'driving',
    )
    .then(() => null)
    .catch((caught: unknown) => caught);

  assertEquals(error instanceof Error, true);
  const details = (error as { details?: Record<string, unknown> }).details;
  assertEquals(details?.status, 400);
  assertEquals(details?.provider_status, 'INVALID_ARGUMENT');
  assertEquals(
    details?.provider_message,
    "Invalid value at 'polyline_quality' (\"HIGH\")",
  );
});

Deno.test('requestJson scrubs coordinates out of the provider message', async () => {
  const client = new GoogleMapsClient({
    apiKey: 'test-key',
    routesBaseUrl: 'https://routes.example',
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: {
            code: 400,
            message: "Invalid value at 'origin.location.lat_lng.latitude' (-6.792400)",
            status: 'INVALID_ARGUMENT',
          },
        }),
        { status: 400, headers: { 'content-type': 'application/json' } },
      ),
  });

  const error = await client
    .calculateRoute(
      { lat: -6.7924, lng: 39.2083 },
      { lat: -6.761, lng: 39.276 },
      'driving',
    )
    .then(() => null)
    .catch((caught: unknown) => caught);

  const details = (error as { details?: Record<string, unknown> }).details;
  assertEquals(details?.provider_message, "Invalid value at 'origin.location.lat_lng.latitude' ([redacted])");
});
