import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { type SupabaseClient, userClient } from '../_shared/db.ts';
import { ForbiddenError, ValidationError } from '../_shared/errors.ts';
import { created } from '../_shared/response.ts';
import { parseJsonBody, tripShareSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface TripShareDeps {
  auth?: AuthDeps;
  userClient?: (jwt: string) => SupabaseClient;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: TripShareDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, tripShareSchema);
  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);

  const { data, error } = await client.rpc('create_trip_share_token', {
    p_job_id: body.job_id,
  });
  if (error) {
    if (error.code === '42501') {
      throw new ForbiddenError('You are not a participant on this job');
    }
    throw error;
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!row?.token) {
    throw new ValidationError('Unable to create a trip share token');
  }

  const base = (Deno.env.get('PUBLIC_TRACKING_BASE_URL') ?? 'http://localhost:3001/trip').replace(/\/$/, '');
  return created({
    token: row.token,
    expires_at: row.expires_at,
    share_url: `${base}/${row.token}`,
  });
}
