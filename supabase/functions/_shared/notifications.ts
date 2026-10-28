import { InternalError, NotFoundError, ProviderError } from './errors.ts';
import type { SupabaseClient } from './db.ts';
import type { BeemClient } from './providers/beem.ts';
import type { AfricaSTalkingClient } from './providers/africastalking.ts';
import type { ResendClient } from './providers/resend.ts';
import type { FcmClient } from './providers/fcm.ts';

export interface NotificationLogRow {
  public_id: string;
  profile_id: string;
  channel: 'push' | 'sms' | 'email';
  recipient: string;
  subject: string | null;
  body: string;
  status: string;
  provider: string | null;
  reference_type: string | null;
  reference_id: string | null;
}

export interface DeliveryClients {
  beem?: BeemClient;
  africaSTalking?: AfricaSTalkingClient;
  resend?: ResendClient;
  fcm?: FcmClient;
}

export async function loadNotification(
  service: SupabaseClient,
  publicId: string,
): Promise<NotificationLogRow> {
  const { data, error } = await service
    .from('notification_log')
    .select(
      'public_id, profile_id, channel, recipient, subject, body, status, provider, reference_type, reference_id',
    )
    .eq('public_id', publicId)
    .maybeSingle();

  if (error) throw new InternalError('Unable to read notification log');
  if (!data) throw new NotFoundError('Notification not found');
  return data as NotificationLogRow;
}

export async function updateNotification(
  service: SupabaseClient,
  publicId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await service.from('notification_log').update(patch).eq('public_id', publicId);
  if (error) throw new InternalError('Unable to update notification log');
}

export async function deliverSms(
  service: SupabaseClient,
  row: NotificationLogRow,
  clients: DeliveryClients,
): Promise<{ notification_id: string; status: string; provider_used: string }> {
  let beemResult;
  let beemError: unknown;
  try {
    if (!clients.beem) throw new ProviderError('beem', 'Beem client is not configured');
    beemResult = await clients.beem.sendSms(row.recipient, '', row.body, row.public_id);
  } catch (error) {
    beemError = error;
  }

  if (beemResult) {
    // Persisting the result is separate from the send so a database failure
    // cannot trigger a duplicate SMS through the fallback provider.
    await updateNotification(service, row.public_id, {
      status: 'sent',
      provider: 'beem',
      provider_message_id: beemResult.provider_message_id,
      provider_response: { status: beemResult.status },
      sent_at: new Date().toISOString(),
    });
    return { notification_id: row.public_id, status: 'sent', provider_used: 'beem' };
  }

  let fallbackResult;
  let fallbackError: unknown;
  try {
    if (!clients.africaSTalking) {
      throw new ProviderError('africastalking', "Africa's Talking client is not configured");
    }
    fallbackResult = await clients.africaSTalking.sendSms(
      row.recipient,
      '',
      row.body,
      row.public_id,
    );
  } catch (error) {
    fallbackError = error;
  }

  if (fallbackResult) {
    await updateNotification(service, row.public_id, {
      status: 'sent',
      provider: 'africastalking',
      provider_message_id: fallbackResult.provider_message_id,
      provider_response: { status: fallbackResult.status, failover: true },
      sent_at: new Date().toISOString(),
    });
    return { notification_id: row.public_id, status: 'sent', provider_used: 'africastalking' };
  }

  await updateNotification(service, row.public_id, {
    status: 'failed',
    provider: 'africastalking',
    failure_reason: 'beem_and_africastalking_failed',
    provider_response: { failover: true },
  });
  throw new ProviderError('sms', 'Both SMS providers failed', {
    beem: beemError instanceof Error ? beemError.name : 'unknown',
    africastalking: fallbackError instanceof Error ? fallbackError.name : 'unknown',
  });
}

export async function deliverEmail(
  service: SupabaseClient,
  row: NotificationLogRow,
  clients: DeliveryClients,
): Promise<{ notification_id: string; status: string; provider_used: string }> {
  try {
    if (!clients.resend) throw new ProviderError('resend', 'Resend client is not configured');
    const subject = row.subject ?? 'SafeShift notification';
    const result = await clients.resend.sendEmail(
      row.recipient,
      '',
      subject,
      row.body,
      row.body,
      row.public_id,
    );
    await updateNotification(service, row.public_id, {
      status: 'sent',
      provider: 'resend',
      provider_message_id: result.provider_message_id,
      provider_response: { status: result.status },
      sent_at: new Date().toISOString(),
    });
    return { notification_id: row.public_id, status: 'sent', provider_used: 'resend' };
  } catch (error) {
    await updateNotification(service, row.public_id, {
      status: 'failed',
      provider: 'resend',
      failure_reason: 'resend_failed',
    });
    throw error;
  }
}

export async function deliverPush(
  service: SupabaseClient,
  row: NotificationLogRow,
  clients: DeliveryClients,
  data: Record<string, string> = {},
  deepLink?: string,
): Promise<{ notification_id: string; status: string; provider_used: string }> {
  try {
    if (!clients.fcm) throw new ProviderError('fcm', 'FCM client is not configured');
    const result = await clients.fcm.sendToToken(
      row.recipient,
      row.subject ?? 'SafeShift',
      row.body,
      data,
      deepLink,
    );
    await updateNotification(service, row.public_id, {
      status: 'sent',
      provider: 'fcm',
      provider_message_id: result.provider_message_id,
      provider_response: { status: result.status },
      sent_at: new Date().toISOString(),
    });
    return { notification_id: row.public_id, status: 'sent', provider_used: 'fcm' };
  } catch (error) {
    await updateNotification(service, row.public_id, {
      status: 'failed',
      provider: 'fcm',
      failure_reason: 'fcm_failed',
    });

    const status = (error as { details?: { status?: number } }).details?.status;
    if (status === 400 || status === 404) {
      await service.from('push_tokens').update({ is_active: false }).eq('token', row.recipient);
    }
    throw error;
  }
}
