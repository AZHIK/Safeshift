# maps-distance

Returns Google Routes API `computeRouteMatrix` results for up to 25 origins and 25 destinations.

- **Auth:** bearer JWT.
- **Method:** `POST`.
- **Body:** `{ origins: [{lat,lng}], destinations: [{lat,lng}], mode? }`. `mode` is `driving`,
  `walking`, `bicycling`, or `transit`.
- **Secrets:** `GOOGLE_MAPS_API_KEY` from the environment or Vault.
- **Cache:** exact route + mode rows in `distance_cache` for seven days.

The response contains `distance_km`, `duration_min`, and `cached`. Cache reads and writes use the
service role; the caller never receives a provider key.
