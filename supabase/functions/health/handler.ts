import { AppError } from '../_shared/errors.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { jsonResponse, success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface HealthDeps {
  service?: SupabaseClient;
  now?: () => Date;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: HealthDeps = {},
): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    throw new AppError(405, 'method_not_allowed', 'Use GET');
  }

  const service = deps.service ?? serviceClient();
  const now = deps.now ?? (() => new Date());
  let db = false;
  let vault = false;

  try {
    const { error } = await service
      .from('countries')
      .select('id', { head: true, count: 'exact' })
      .limit(1);
    db = !error;
  } catch {
    db = false;
  }

  try {
    const { data, error } = await service.rpc('get_vault_secret', {
      p_name: 'safeshift_healthcheck',
    });
    vault = !error && data === 'ok';
  } catch {
    vault = false;
  }

  const status = db && vault ? 'ok' : 'degraded';
  const body = {
    status,
    checks: {
      db,
      vault,
      timestamp: now().toISOString(),
    },
  };

  return db && vault ? success(body) : jsonResponse(503, { data: body, error: null });
}
