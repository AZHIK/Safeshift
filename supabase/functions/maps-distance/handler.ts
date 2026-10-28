import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { RequestLogger } from '../_shared/logger.ts';
import { getCachedDistance, storeDistance } from '../_shared/maps_cache.ts';
import { googleMapsClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { mapsDistanceSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';
import type { GoogleMapsClient } from '../_shared/providers/google_maps.ts';

export interface MapsDistanceDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  maps?: GoogleMapsClient;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: MapsDistanceDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, mapsDistanceSchema);
  const service = deps.service ?? serviceClient();
  const logger = new RequestLogger(ctx.functionName, ctx.requestId, ctx.startedAt);
  const origin = body.origins[0];
  const destination = body.destinations[0];

  const mode = body.mode ?? 'driving';
  const cacheable = body.origins.length === 1 && body.destinations.length === 1;
  const cached = cacheable ? await getCachedDistance(service, origin, destination, mode) : null;
  if (cached) {
    logger.info('distance_cache_hit', { user_id: auth.userId });
    return success({ ...cached, cached: true });
  }

  const maps = deps.maps ?? await googleMapsClient(ctx.requestId);
  const result = await maps.calculateDistance(body.origins, body.destinations, mode);

  if (cacheable) {
    try {
      await storeDistance(service, origin, destination, mode, result);
    } catch (error) {
      logger.warn('distance_cache_write_failed', {
        error_type: error instanceof Error ? error.name : 'unknown',
      });
    }
  }

  return success({ ...result, cached: false });
}
