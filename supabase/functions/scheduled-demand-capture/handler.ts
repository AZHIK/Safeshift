import { type AuthDeps, defaultAuthDeps, requireServiceRole } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface ScheduledDemandCaptureDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  now?: () => Date;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: ScheduledDemandCaptureDeps = {},
): Promise<Response> {
  await requireServiceRole(req, deps.auth ?? defaultAuthDeps());
  const service = deps.service ?? serviceClient();
  const now = deps.now ?? (() => new Date());

  const { data, error } = await service.rpc('capture_demand_snapshot');
  if (error) throw error;

  return success({
    snapshots_captured: Number(data ?? 0),
    captured_at: now().toISOString(),
  });
}
