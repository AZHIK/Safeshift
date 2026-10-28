# quote-calculate

Calculates a priced quote through the Phase 4 `quote_calculate_and_persist` RPC.

- **Auth:** bearer JWT with the `customer` or `business` profile role.
- **Method:** `POST`.
- **Body:** pickup and destination coordinates/addresses, `vehicle_type_id`, and optional cargo,
  scheduling, stops, waiting, equipment, and promo fields.
- **Secrets:** `GOOGLE_MAPS_API_KEY` when the caller does not inject a distance.
- **Response:** `201` with `{ quote_id, breakdown, expires_at }`.

The function reuses the service-role client for `distance_cache`, then calls the Phase 4 RPC with
the user's JWT so pricing, promo, and country rules remain database-enforced. The RPC returns only
the quote id; the handler reads the persisted snapshot for the breakdown.
