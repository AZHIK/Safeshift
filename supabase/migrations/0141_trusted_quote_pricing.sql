-- Road distance and duration affect the final fare. They must be supplied by
-- trusted server code after a Maps lookup, never by an authenticated client.
-- The quote-calculate Edge Function validates the user, obtains the route,
-- then calls this RPC with the service role. Existing quotes remain readable
-- through quote_get_breakdown and normal RLS.
revoke all on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) from authenticated;

grant execute on function public.quote_calculate_and_persist(
  uuid, extensions.geography, text, extensions.geography, text,
  uuid, uuid, numeric, numeric, timestamptz, integer, integer,
  uuid[], uuid, numeric, numeric, text, numeric, text[]
) to service_role;
