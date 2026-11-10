# maps-route

Returns Google Routes API `Compute Routes` geometry plus distance and duration for one driving route.

- **Auth:** bearer JWT.
- **Method:** `POST`.
- **Body:** `{ origin: {lat, lng}, destination: {lat, lng}, mode?: 'driving' }`.
- **Response:** `{ distance_km, duration_min, encoded_polyline, route_label?, traffic_aware, cached }`.
- **Secrets:** `GOOGLE_MAPS_API_KEY` from the environment or Vault.
- **Cache:** this function does not cache results. Callers may memoize by endpoint pair; cache invalidation happens automatically when either endpoint changes.

The encoded polyline uses Google's encoded polyline algorithm and describes the actual road-following route. It must be decoded client-side before rendering.

Provider details:

- Endpoint: `POST https://routes.googleapis.com/directions/v2:computeRoutes`. There is no
  `/v1:computeRoutes` path — requesting it returns a 404 with an empty body.
- `polylineQuality` is an enum. The only spellings Google accepts are
  `POLYLINE_QUALITY_UNSPECIFIED` and `HIGH_QUALITY`; `HIGH` is rejected with
  `INVALID_ARGUMENT`.
- The Routes API has its own host. `GOOGLE_MAPS_ROUTES_BASE_URL` overrides it; it must never
  fall back to `GOOGLE_MAPS_BASE_URL`, which is the Geocoding/Places host.
- `traffic_aware` is true when the route was computed with `TRAFFIC_AWARE` routing.

When the provider rejects the request, the response carries `error.details.provider_status`
and `error.details.provider_message` so the failure is diagnosable. Coordinate-shaped numbers
are scrubbed from the provider message.

Never log or return the provider API key.
