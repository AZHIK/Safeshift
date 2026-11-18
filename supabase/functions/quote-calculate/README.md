# quote-calculate

Calculates a priced quote through the Phase 4 `quote_calculate_and_persist` RPC.

- **Auth:** bearer JWT with the `customer` or `business` profile role.
- **Method:** `POST`.
- **Body:** pickup and destination coordinates/addresses, `vehicle_type_id`, and optional cargo,
  declared value, scheduling, stops, waiting, equipment, and promo fields. Client distance and
  duration values are ignored.
- **Secrets:** Google Maps key in Vault and the Supabase service-role key.
- **Response:** `201` with `{ quote_id, breakdown, expires_at }`.

The function validates the user's JWT and profile, obtains a server-side road distance, then calls
the pricing RPC with the service role. Direct authenticated execution of that RPC is revoked so a
client cannot forge the distance used to calculate the fare. The handler reads the persisted
snapshot through the user's JWT and RLS before returning it.
