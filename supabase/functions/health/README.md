# health

Public liveness/readiness probe for the Edge Function runtime and database.

- **Auth:** none. This is the only intentionally public non-webhook function.
- **Method:** `GET`.
- **Secrets:** reads the `safeshift_healthcheck` Vault secret through the service-role-only
  `get_vault_secret` RPC.
- **Response:** `{ data: { status, database, vault, version, checked_at }, error }`.

`status` is `ok` when the database RPC and Vault read succeed. A degraded response still uses the
shared envelope and reports the failed component without exposing secret values.
