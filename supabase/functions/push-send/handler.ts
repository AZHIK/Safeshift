import {
  type AuthDeps,
  defaultAuthDeps,
  requireAdmin,
  requireInternalSecret,
} from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { NotFoundError, ProviderError } from '../_shared/errors.ts';
import { deliverPush, type DeliveryClients, loadNotification } from '../_shared/notifications.ts';
import { insertNotificationLog } from '../_shared/notification_request.ts';
import { fcmClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, pushSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface PushSendDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  clients?: DeliveryClients;
}

interface TokenRow {
  profile_id: string;
  token: string;
}

async function authorize(req: Request, deps: PushSendDeps): Promise<void> {
  try {
    await requireAdmin(req, 'send_push', deps.auth ?? defaultAuthDeps());
  } catch (error) {
    if (!req.headers.get('x-internal-secret')) throw error;
    await requireInternalSecret(req, deps.auth ?? defaultAuthDeps());
  }
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: PushSendDeps = {},
): Promise<Response> {
  await authorize(req, deps);
  const body = await parseJsonBody(req, pushSchema);
  const service = deps.service ?? serviceClient();

  let tokens: TokenRow[] = [];
  if (body.device_token) {
    const { data, error } = await service
      .from('push_tokens')
      .select('profile_id, token')
      .eq('token', body.device_token)
      .eq('is_active', true)
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new NotFoundError('Active push token not found');
    tokens = [data as TokenRow];
  } else if (body.profile_id) {
    const { data, error } = await service
      .from('push_tokens')
      .select('profile_id, token')
      .eq('profile_id', body.profile_id)
      .eq('is_active', true);
    if (error) throw error;
    tokens = (data ?? []) as TokenRow[];
    if (tokens.length === 0) throw new NotFoundError('No active push tokens for profile');
  }

  const clients = deps.clients ?? { fcm: await fcmClient(ctx.requestId) };
  let sentCount = 0;
  let failedCount = 0;
  let firstNotificationId: string | null = null;

  for (const token of tokens) {
    const publicId = await insertNotificationLog(service, {
      profileId: token.profile_id,
      channel: 'push',
      recipient: token.token,
      subject: body.title,
      body: body.body,
      provider: 'fcm',
    });
    if (!firstNotificationId) firstNotificationId = publicId;

    try {
      const row = await loadNotification(service, publicId);
      await deliverPush(service, row, clients, body.data ?? {}, body.deep_link);
      sentCount += 1;
    } catch {
      failedCount += 1;
    }
  }

  if (sentCount === 0) {
    throw new ProviderError('fcm', 'Push delivery failed for every active token', {
      failed_count: failedCount,
    });
  }

  return success({
    notification_id: firstNotificationId,
    sent_count: sentCount,
    failed_count: failedCount,
  });
}
