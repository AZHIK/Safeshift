# maps-geocode

Forward-geocodes an address or reverse-geocodes a coordinate pair.

- **Auth:** bearer JWT.
- **Method:** `POST`.
- **Body:** either `{ address }` or `{ lat, lng }`.
- **Secrets:** `GOOGLE_MAPS_API_KEY` from the environment or Vault.
- **Cache:** `geocoding_cache` for 30 days, keyed by lower-cased address or exact reverse
  coordinates.

The response includes `lat`, `lng`, `formatted_address`, and `cached`. Invalid or empty results are
returned as `422 validation_error`.
