import {
  type AuthDeps,
  defaultAuthDeps,
  requireAdmin,
  requireInternalSecret,
} from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { ValidationError } from '../_shared/errors.ts';
import { deliverEmail, type DeliveryClients, loadNotification } from '../_shared/notifications.ts';
import { insertNotificationLog, resolveProfileId } from '../_shared/notification_request.ts';
import { resendClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { emailSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface EmailSendDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  clients?: DeliveryClients;
}

async function authorize(req: Request, deps: EmailSendDeps): Promise<void> {
  try {
    await requireAdmin(req, 'send_email', deps.auth ?? defaultAuthDeps());
  } catch (error) {
    if (!req.headers.get('x-internal-secret')) throw error;
    await requireInternalSecret(req, deps.auth ?? defaultAuthDeps());
  }
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: EmailSendDeps = {},
): Promise<Response> {
  await authorize(req, deps);
  const body = await parseJsonBody(req, emailSchema);
  const service = deps.service ?? serviceClient();

  if (body.template_code) {
    const profileId = await resolveProfileId(service, body.profile_id, { email: body.to });
    const { data: publicId, error } = await service.rpc('send_notification', {
      p_profile_id: profileId,
      p_template_code: body.template_code,
      p_channel: 'email',
      p_variables: body.variables ?? {},
      p_reference_type: body.reference_type ?? null,
      p_reference_id: body.reference_id ?? null,
    });
    if (error) throw error;
    if (!publicId) {
      return success({ notification_id: null, status: 'skipped', provider_used: null });
    }

    const row = await loadNotification(service, String(publicId));
    const clients = deps.clients ?? { resend: await resendClient(ctx.requestId) };
    return success(await deliverEmail(service, row, clients));
  }

  if (!body.to || (!body.html && !body.text) || !body.subject) {
    throw new ValidationError(
      'to, subject, and html or text are required when template_code is omitted',
    );
  }

  const profileId = await resolveProfileId(service, body.profile_id, { email: body.to });
  const publicId = await insertNotificationLog(service, {
    profileId,
    channel: 'email',
    recipient: body.to,
    subject: body.subject,
    body: body.html ?? body.text ?? '',
    templateCode: null,
    provider: 'resend',
    referenceType: body.reference_type ?? null,
    referenceId: body.reference_id ?? null,
  });
  const row = await loadNotification(service, publicId);
  const clients = deps.clients ?? { resend: await resendClient(ctx.requestId) };
  return success(await deliverEmail(service, row, clients));
}
