import { InternalError, NotFoundError } from './errors.ts';
import type { SupabaseClient } from './db.ts';

export async function resolveProfileId(
  service: SupabaseClient,
  profileId: string | undefined,
  contact: { phone?: string; email?: string },
): Promise<string> {
  if (profileId) return profileId;

  if (contact.phone) {
    const { data, error } = await service
      .from('profiles')
      .select('id')
      .eq('phone', contact.phone)
      .maybeSingle();
    if (!error && data?.id) return data.id;
  }

  if (contact.email) {
    const { data, error } = await service
      .from('profiles')
      .select('id')
      .eq('email', contact.email)
      .maybeSingle();
    if (!error && data?.id) return data.id;
  }

  throw new NotFoundError('No profile matches the supplied recipient');
}

export async function insertNotificationLog(
  service: SupabaseClient,
  input: {
    profileId: string;
    channel: 'push' | 'sms' | 'email';
    recipient: string;
    body: string;
    subject?: string | null;
    templateCode?: string | null;
    provider: string;
    referenceType?: string | null;
    referenceId?: string | null;
  },
): Promise<string> {
  const { data, error } = await service
    .from('notification_log')
    .insert({
      profile_id: input.profileId,
      channel: input.channel,
      recipient: input.recipient,
      subject: input.subject ?? null,
      body: input.body,
      status: 'pending',
      provider: input.provider,
      template_code: input.templateCode ?? null,
      reference_type: input.referenceType ?? null,
      reference_id: input.referenceId ?? null,
    })
    .select('public_id')
    .single();

  if (error) throw error;
  if (!data?.public_id) throw new InternalError('Unable to create notification log row');
  return data.public_id as string;
}
