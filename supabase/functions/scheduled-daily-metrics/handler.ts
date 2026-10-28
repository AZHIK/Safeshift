import { type AuthDeps, defaultAuthDeps, requireServiceRole } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface ScheduledDailyMetricsDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  now?: () => Date;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: ScheduledDailyMetricsDeps = {},
): Promise<Response> {
  await requireServiceRole(req, deps.auth ?? defaultAuthDeps());
  const service = deps.service ?? serviceClient();
  const now = deps.now ?? (() => new Date());
  const targetDate = new Date(now().getTime() - 24 * 60 * 60 * 1_000)
    .toISOString()
    .slice(0, 10);

  const { data: daily, error: dailyError } = await service.rpc('compute_daily_metrics', {
    p_target_date: targetDate,
  });
  if (dailyError) throw dailyError;

  const { data: zones, error: zoneError } = await service.rpc('compute_zone_metrics', {
    p_target_date: targetDate,
  });
  if (zoneError) throw zoneError;

  const { data: drivers, error: driverError } = await service.rpc('compute_driver_metrics', {
    p_target_date: targetDate,
  });
  if (driverError) throw driverError;

  const { data: customers, error: customerError } = await service.rpc('compute_customer_metrics', {
    p_target_date: targetDate,
  });
  if (customerError) throw customerError;

  return success({
    target_date: targetDate,
    daily_metrics_rows: Number(daily ?? 0),
    zone_metrics_rows: Number(zones ?? 0),
    driver_metrics_rows: Number(drivers ?? 0),
    customer_metrics_rows: Number(customers ?? 0),
    completed_at: now().toISOString(),
  });
}
