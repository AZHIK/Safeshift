# auth-validate

Validates the caller's Supabase JWT and returns the hydrated authorization context used by the
Flutter apps.

- **Auth:** bearer JWT.
- **Method:** `GET`.
- **Response:** `{ data: { userId, role, countryId, permissions, isActive }, error }`.
- **Permissions:** reads `public.current_permissions()` with the caller's JWT so role, country,
  city, and permission checks are evaluated by the database.

Returns `401 unauthorized` for a missing, malformed, expired, or inactive profile. Permissions are
never trusted from JWT claims.
