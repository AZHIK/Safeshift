import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { RequestLogger } from '../_shared/logger.ts';
import {
  getCachedForwardGeocode,
  getCachedReverseGeocode,
  storeForwardGeocode,
  storeReverseGeocode,
} from '../_shared/maps_cache.ts';
import { googleMapsClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { mapsGeocodeSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';
import type { GoogleMapsClient } from '../_shared/providers/google_maps.ts';

export interface MapsGeocodeDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  maps?: GoogleMapsClient;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: MapsGeocodeDeps = {},
): Promise<Response> {
  await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, mapsGeocodeSchema);
  const service = deps.service ?? serviceClient();
  const logger = new RequestLogger(ctx.functionName, ctx.requestId, ctx.startedAt);

  if ('address' in body) {
    const cached = await getCachedForwardGeocode(service, body.address);
    if (cached) return success({ ...cached, cached: true });

    const maps = deps.maps ?? await googleMapsClient(ctx.requestId);
    const result = await maps.geocode(body.address);
    try {
      await storeForwardGeocode(service, body.address, result);
    } catch (error) {
      logger.warn('geocode_cache_write_failed', {
        error_type: error instanceof Error ? error.name : 'unknown',
      });
    }
    return success({ ...result, cached: false });
  }

  const cached = await getCachedReverseGeocode(service, body.lat, body.lng);
  if (cached) return success({ ...cached, cached: true });

  const maps = deps.maps ?? await googleMapsClient(ctx.requestId);
  const result = await maps.reverseGeocode(body.lat, body.lng);
  try {
    await storeReverseGeocode(service, body.lat, body.lng, result);
  } catch (error) {
    logger.warn('geocode_cache_write_failed', {
      error_type: error instanceof Error ? error.name : 'unknown',
    });
  }
  return success({ ...result, cached: false });
}
