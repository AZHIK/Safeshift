import { type AuthDeps, defaultAuthDeps, requireAdmin } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { ProviderError } from '../_shared/errors.ts';
import {
  deliverEmail,
  deliverPush,
  deliverSms,
  type DeliveryClients,
  loadNotification,
  type NotificationLogRow,
} from '../_shared/notifications.ts';
import {
  africaSTalkingClient,
  beemClient,
  fcmClient,
  resendClient,
} from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { notificationDispatchSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface NotificationDispatchDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  clients?: DeliveryClients;
  deliver?: (
    channel: 'push' | 'sms' | 'email',
    row: NotificationLogRow,
    service: SupabaseClient,
  ) => Promise<{ notification_id: string; status: string; provider_used: string }>;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: NotificationDispatchDeps = {},
): Promise<Response> {
  await requireAdmin(req, 'send_notification', deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, notificationDispatchSchema);
  const service = deps.service ?? serviceClient();
  const clients = deps.clients ?? await buildClients(ctx.requestId);

  const notificationIds: string[] = [];
  const channelsUsed: string[] = [];
  const failures: Array<{ channel: string; code: string }> = [];

  for (const channel of [...new Set(body.channels)]) {
    const { data: publicId, error } = await service.rpc('send_notification', {
      p_profile_id: body.profile_id,
      p_template_code: body.template_code,
      p_channel: channel,
      p_variables: body.variables,
      p_reference_type: body.reference_type ?? null,
      p_reference_id: body.reference_id ?? null,
    });

    if (error) {
      failures.push({ channel, code: 'rpc_failed' });
      continue;
    }
    if (!publicId) {
      // Disabled preference or quiet hours. This is a successful skip.
      continue;
    }

    const id = String(publicId);
    notificationIds.push(id);
    channelsUsed.push(channel);

    try {
      const row = await loadNotification(service, id);
      if (deps.deliver) {
        await deps.deliver(channel, row, service);
      } else if (channel === 'sms') {
        await deliverSms(service, row, clients);
      } else if (channel === 'email') {
        await deliverEmail(service, row, clients);
      } else {
        await deliverPush(service, row, clients);
      }
    } catch (error) {
      failures.push({
        channel,
        code: error instanceof Error ? error.name : 'delivery_failed',
      });
    }
  }

  if (notificationIds.length === 0 && failures.length > 0) {
    throw new ProviderError('notification', 'Every requested channel failed', { failures });
  }

  return success({ notification_ids: notificationIds, channels_used: channelsUsed, failures });
}

async function buildClients(requestId: string): Promise<DeliveryClients> {
  const clients: DeliveryClients = {};
  const results = await Promise.allSettled([
    beemClient(requestId),
    africaSTalkingClient(requestId),
    resendClient(requestId),
    fcmClient(requestId),
  ]);
  if (results[0].status === 'fulfilled') clients.beem = results[0].value;
  if (results[1].status === 'fulfilled') clients.africaSTalking = results[1].value;
  if (results[2].status === 'fulfilled') clients.resend = results[2].value;
  if (results[3].status === 'fulfilled') clients.fcm = results[3].value;
  return clients;
}
