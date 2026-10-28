import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient, userClient } from '../_shared/db.ts';
import { ForbiddenError, InternalError } from '../_shared/errors.ts';
import { getCachedDistance, storeDistance } from '../_shared/maps_cache.ts';
import { googleMapsClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, quoteSchema } from '../_shared/validation.ts';
import type { DistanceResult, RequestContext } from '../_shared/types/index.ts';

export interface QuoteCalculateDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  userClient?: (jwt: string) => SupabaseClient;
  mapsDistance?: (
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ) => Promise<DistanceResult>;
}

function geography(point: { lat: number; lng: number }): string {
  return `SRID=4326;POINT(${point.lng} ${point.lat})`;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: QuoteCalculateDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  if (auth.role !== 'customer' && auth.role !== 'business') {
    throw new ForbiddenError('Only customer or business profiles may create quotes');
  }

  const body = await parseJsonBody(req, quoteSchema);
  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);

  const distance = deps.mapsDistance
    ? await deps.mapsDistance(body.pickup, body.destination)
    : await (async () => {
      const cache = deps.service ?? serviceClient();
      const cached = await getCachedDistance(
        cache,
        body.pickup,
        body.destination,
        'driving',
      );
      if (cached) return cached;
      const maps = await googleMapsClient(ctx.requestId);
      const result = await maps.calculateDistance([body.pickup], [body.destination], 'driving');
      try {
        await storeDistance(cache, body.pickup, body.destination, 'driving', result);
      } catch {
        // Cache is an optimization; quote creation must still succeed.
      }
      return result;
    })();

  const { data: quoteId, error } = await client.rpc('quote_calculate_and_persist', {
    p_customer_id: auth.userId,
    p_pickup_location: geography(body.pickup),
    p_pickup_address: body.pickup.address,
    p_destination_location: geography(body.destination),
    p_destination_address: body.destination.address,
    p_vehicle_type_id: body.vehicle_type_id,
    p_cargo_type_id: body.cargo_type_id ?? null,
    p_cargo_weight_kg: body.cargo_weight_kg ?? null,
    p_cargo_volume_m3: body.cargo_volume_m3 ?? null,
    p_scheduled_at: body.scheduled_at ?? null,
    p_stop_count: body.stop_count ?? 2,
    p_waiting_minutes: body.waiting_minutes ?? 0,
    p_equipment_ids: body.equipment_ids ?? [],
    p_promo_code_id: body.promo_code_id ?? null,
    p_distance_km: distance.distance_km,
    p_duration_min: distance.duration_min,
  });

  if (error) throw error;
  if (!quoteId) throw new InternalError('Quote RPC returned no identifier');

  const { data: quote, error: quoteError } = await client
    .from('quotes')
    .select('pricing_breakdown_snapshot, expires_at')
    .eq('id', quoteId)
    .single();

  if (quoteError) throw quoteError;
  if (!quote) throw new InternalError('Unable to read persisted quote');

  return success({
    quote_id: quoteId,
    breakdown: quote.pricing_breakdown_snapshot,
    expires_at: quote.expires_at,
  }, 201);
}
