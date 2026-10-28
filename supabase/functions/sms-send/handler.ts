import {
  type AuthDeps,
  defaultAuthDeps,
  requireAdmin,
  requireInternalSecret,
} from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { ValidationError } from '../_shared/errors.ts';
import { deliverSms, type DeliveryClients, loadNotification } from '../_shared/notifications.ts';
import { insertNotificationLog, resolveProfileId } from '../_shared/notification_request.ts';
import { africaSTalkingClient, beemClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, smsSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface SmsSendDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  clients?: DeliveryClients;
}

async function authorize(req: Request, deps: SmsSendDeps): Promise<void> {
  try {
    await requireAdmin(req, 'send_sms', deps.auth ?? defaultAuthDeps());
  } catch (error) {
    if (!req.headers.get('x-internal-secret')) throw error;
    await requireInternalSecret(req, deps.auth ?? defaultAuthDeps());
  }
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: SmsSendDeps = {},
): Promise<Response> {
  await authorize(req, deps);
  const body = await parseJsonBody(req, smsSchema);
  const service = deps.service ?? serviceClient();

  if (body.template_code) {
    const profileId = await resolveProfileId(service, body.profile_id, { phone: body.to });
    const { data: publicId, error } = await service.rpc('send_notification', {
      p_profile_id: profileId,
      p_template_code: body.template_code,
      p_channel: 'sms',
      p_variables: body.variables ?? {},
      p_reference_type: body.reference_type ?? null,
      p_reference_id: body.reference_id ?? null,
    });
    if (error) throw error;
    if (!publicId) {
      return success({ notification_id: null, status: 'skipped', provider_used: null });
    }

    const row = await loadNotification(service, String(publicId));
    const clients = deps.clients ?? await buildClients(ctx.requestId);
    return success(await deliverSms(service, row, clients));
  }

  if (!body.to || !body.body) {
    throw new ValidationError('to and body are required when template_code is omitted');
  }

  const profileId = await resolveProfileId(service, body.profile_id, { phone: body.to });
  const publicId = await insertNotificationLog(service, {
    profileId,
    channel: 'sms',
    recipient: body.to,
    body: body.body,
    templateCode: body.template_code ?? null,
    provider: 'beem',
    referenceType: body.reference_type ?? null,
    referenceId: body.reference_id ?? null,
  });
  const row = await loadNotification(service, publicId);
  const clients = deps.clients ?? await buildClients(ctx.requestId);
  return success(await deliverSms(service, row, clients));
}

async function buildClients(requestId: string): Promise<DeliveryClients> {
  const clients: DeliveryClients = {};
  try {
    clients.beem = await beemClient(requestId);
  } catch {
    // Fallback provider is still attempted.
  }
  try {
    clients.africaSTalking = await africaSTalkingClient(requestId);
  } catch {
    // deliverSms reports both-provider failure.
  }
  return clients;
}
