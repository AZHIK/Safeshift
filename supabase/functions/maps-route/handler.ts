import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { RequestLogger } from '../_shared/logger.ts';
import { googleMapsClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { mapsRouteSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';
import type { GoogleMapsClient } from '../_shared/providers/google_maps.ts';

export interface MapsRouteDeps {
  auth?: AuthDeps;
  maps?: GoogleMapsClient;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: MapsRouteDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, mapsRouteSchema);
  const logger = new RequestLogger(ctx.functionName, ctx.requestId, ctx.startedAt);

  const origin = body.origin;
  const destination = body.destination;

  const maps = deps.maps ?? await googleMapsClient(ctx.requestId);
  const result = await maps.calculateRoute(origin, destination, body.mode);

  logger.info('route_computed', {
    user_id: auth.userId,
    distance_km: result.distance_km,
    duration_min: result.duration_min,
    route_label: result.route_label,
    traffic_aware: result.traffic_aware,
  });

  return success({
    ...result,
    cached: false,
  });
}
