import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { ForbiddenError, NotFoundError } from '../_shared/errors.ts';
import {
  deliverPush,
  deliverSms,
  type DeliveryClients,
  loadNotification,
} from '../_shared/notifications.ts';
import { insertNotificationLog } from '../_shared/notification_request.ts';
import { beemClient, africaSTalkingClient, fcmClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, sosAlertSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface SosAlertDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  clients?: DeliveryClients;
}

interface AlertRow {
  id: string;
  job_id: string;
  profile_id: string;
  status: string;
  details: string | null;
}

interface ContactRow {
  id: string;
  name: string;
  phone: string;
  notify_on_sos: boolean;
}

async function optionalClients(): Promise<DeliveryClients> {
  const clients: DeliveryClients = {};
  try {
    clients.beem = await beemClient();
  } catch {
    // Provider credentials are optional in local development.
  }
  try {
    clients.africaSTalking = await africaSTalkingClient();
  } catch {
    // Fallback provider is optional too.
  }
  try {
    clients.fcm = await fcmClient();
  } catch {
    // Push is skipped when FCM is not configured.
  }
  return clients;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: SosAlertDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, sosAlertSchema);
  const service = deps.service ?? serviceClient();
  const clients = deps.clients ?? (await optionalClients());

  const { data: alertData, error: alertError } = await service
    .from('trip_alerts')
    .select('id, job_id, profile_id, status, details')
    .eq('id', body.alert_id)
    .maybeSingle();
  if (alertError) throw alertError;
  if (!alertData) throw new NotFoundError('Safety alert not found');
  const alert = alertData as AlertRow;
  if (alert.profile_id !== auth.userId) {
    throw new ForbiddenError('You may only escalate your own safety alert');
  }

  const { data: jobData, error: jobError } = await service
    .from('jobs')
    .select('id, customer_id, driver_id, quote:quotes!inner(quote_request:quote_requests!inner(pickup_address, destination_address))')
    .eq('id', alert.job_id)
    .maybeSingle();
  if (jobError) throw jobError;
  if (!jobData) throw new NotFoundError('Job not found');

  const quoteRequest = (jobData as {
    quote: { quote_request: { pickup_address: string; destination_address: string } };
  }).quote?.quote_request;
  const route = quoteRequest
    ? `${quoteRequest.pickup_address} → ${quoteRequest.destination_address}`
    : 'an active SafeShift trip';

  const { data: contactsData, error: contactsError } = await service
    .from('emergency_contacts')
    .select('id, name, phone, notify_on_sos')
    .eq('profile_id', auth.userId)
    .eq('notify_on_sos', true);
  if (contactsError) throw contactsError;
  const contacts = (contactsData ?? []) as ContactRow[];

  const smsBody = `SafeShift SAFETY ALERT: ${alert.details ?? 'SOS raised'} on ${route}. Open the app or contact the person immediately.`;
  let smsSent = 0;
  const smsFailures: string[] = [];

  for (const contact of contacts) {
    const notificationId = await insertNotificationLog(service, {
      profileId: auth.userId,
      channel: 'sms',
      recipient: contact.phone,
      body: smsBody,
      subject: 'SafeShift safety alert',
      templateCode: 'sos_emergency_contact',
      provider: 'beem',
      referenceType: 'trip_alert',
      referenceId: alert.id,
    });
    try {
      const row = await loadNotification(service, notificationId);
      const result = await deliverSms(service, row, clients);
      if (result.status === 'sent') smsSent += 1;
    } catch {
      smsFailures.push(contact.id);
    }
  }

  const { data: adminsData, error: adminsError } = await service
    .from('admin_roles')
    .select('profile_id, role_name')
    .eq('is_active', true)
    .in('role_name', ['super_admin', 'operations_admin', 'support_agent'])
    .is('revoked_at', null);
  if (adminsError) throw adminsError;

  const adminIds = Array.from(new Set((adminsData ?? []).map((row) => row.profile_id as string)));
  let pushSent = 0;
  if (adminIds.length > 0) {
    const { data: tokensData, error: tokensError } = await service
      .from('push_tokens')
      .select('profile_id, token')
      .in('profile_id', adminIds)
      .eq('is_active', true);
    if (tokensError) throw tokensError;

    for (const tokenRow of tokensData ?? []) {
      const notificationId = await insertNotificationLog(service, {
        profileId: tokenRow.profile_id as string,
        channel: 'push',
        recipient: tokenRow.token as string,
        subject: 'SafeShift SOS',
        body: `SOS on ${route}. Review the alert in the admin console.`,
        templateCode: 'sos_admin_alert',
        provider: 'fcm',
        referenceType: 'trip_alert',
        referenceId: alert.id,
      });
      try {
        const row = await loadNotification(service, notificationId);
        const result = await deliverPush(service, row, clients, {
          type: 'sos',
          alert_id: alert.id,
          job_id: alert.job_id,
        }, `safeshift://admin/incidents/${alert.id}`);
        if (result.status === 'sent') pushSent += 1;
      } catch {
        // A missing FCM token or provider outage must not fail the SOS write.
      }
    }
  }

  await service
    .from('trip_alerts')
    .update({
      metadata: {
        notified_contacts: smsSent,
        failed_contacts: smsFailures,
        notified_admins: pushSent,
        notified_at: new Date().toISOString(),
      },
    })
    .eq('id', alert.id);

  return success({
    alert_id: alert.id,
    contacts_notified: smsSent,
    contacts_failed: smsFailures.length,
    admins_notified: pushSent,
  });
}
