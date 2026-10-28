import { strToU8, zipSync } from 'npm:fflate@0.8.2';
import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient, userClient } from '../_shared/db.ts';
import { ForbiddenError, NotFoundError, ValidationError } from '../_shared/errors.ts';
import { success } from '../_shared/response.ts';
import { dataExportSchema, parseJsonBody } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface DataExportDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  userClient?: (jwt: string) => SupabaseClient;
  now?: () => Date;
}

interface DsrRow {
  id: string;
  requester_profile_id: string;
  request_type: string;
  status: string;
}

async function canManageDataRequests(
  client: SupabaseClient,
): Promise<boolean> {
  const { data, error } = await client.rpc('has_permission', {
    permission_key: 'manage_data_requests',
  });
  if (error) throw error;
  return data === true;
}

function exportFileName(domain: string): string {
  return `${domain}.json`;
}

function publicDownloadUrl(signedUrl: string): string {
  const publicBase = Deno.env.get('PUBLIC_SUPABASE_URL');
  if (!publicBase) return signedUrl;

  try {
    const target = new URL(signedUrl);
    const base = new URL(publicBase);
    target.protocol = base.protocol;
    target.host = base.host;
    return target.toString();
  } catch {
    return signedUrl;
  }
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: DataExportDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, dataExportSchema);
  const service = deps.service ?? serviceClient();
  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);
  const now = deps.now ?? (() => new Date());

  let request: DsrRow | null = null;
  let profileId: string;

  if (body.request_id) {
    const { data, error } = await service
      .from('data_subject_requests')
      .select('id, requester_profile_id, request_type, status')
      .eq('id', body.request_id)
      .maybeSingle();
    if (error) throw error;
    if (!data) throw new NotFoundError('Data subject request not found');
    request = data as DsrRow;
    profileId = request.requester_profile_id;

    if (profileId !== auth.userId && !(await canManageDataRequests(client))) {
      throw new ForbiddenError('You may only export your own data');
    }
    if (request.request_type !== 'export') {
      throw new ValidationError('Data subject request is not an export request');
    }
  } else {
    profileId = body.profile_id!;
    if (profileId !== auth.userId && !(await canManageDataRequests(client))) {
      throw new ForbiddenError('manage_data_requests permission required');
    }

    const requestNumber = `DSR-${now().getTime()}-${crypto.randomUUID().slice(0, 8)}`;
    const { data, error } = await service
      .from('data_subject_requests')
      .insert({
        request_number: requestNumber,
        requester_profile_id: profileId,
        request_type: 'export',
        status: 'in_progress',
        assigned_to: auth.userId,
      })
      .select('id, requester_profile_id, request_type, status')
      .single();
    if (error || !data) throw error ?? new NotFoundError('Unable to create data subject request');
    request = data as DsrRow;
  }

  const { error: inProgressError } = await service
    .from('data_subject_requests')
    .update({ status: 'in_progress', assigned_to: auth.userId })
    .eq('id', request.id);
  if (inProgressError) throw inProgressError;

  const exportResults = await Promise.all([
    service.from('profiles').select('*').eq('id', profileId).maybeSingle(),
    service.from('saved_addresses').select('*').eq('profile_id', profileId),
    service.from('business_members').select('*').eq('profile_id', profileId),
    service.from('driver_documents').select('*').eq('driver_id', profileId),
    service
      .from('jobs')
      .select('*')
      .or(`customer_id.eq.${profileId},driver_id.eq.${profileId}`),
    service.from('payments').select('*').eq('customer_id', profileId),
    service
      .from('ratings')
      .select('*')
      .or(`rater_profile_id.eq.${profileId},rated_profile_id.eq.${profileId}`),
    service.from('disputes').select('*').eq('raised_by', profileId),
    service.from('support_tickets').select('*').eq('opened_by', profileId),
    service.from('support_ticket_messages').select('*').eq('sender_profile_id', profileId),
    service.from('chat_messages').select('*').eq('sender_profile_id', profileId),
    service.from('consent_records').select('*').eq('profile_id', profileId),
    service
      .from('wallet_transactions')
      .select('*, wallets!inner(profile_id)')
      .eq('wallets.profile_id', profileId),
    service.from('payouts').select('*').eq('driver_id', profileId),
    service.from('notification_log').select('*').eq('profile_id', profileId),
    service.from('push_tokens').select('*').eq('profile_id', profileId),
    service.from('data_subject_requests').select('*').eq('requester_profile_id', profileId),
  ]);

  for (const result of exportResults) {
    if (result.error) throw result.error;
  }

  const [
    profile,
    savedAddresses,
    businessMemberships,
    driverDocuments,
    jobs,
    payments,
    ratings,
    disputes,
    supportTickets,
    supportMessages,
    chatMessages,
    consentRecords,
    walletTransactions,
    payouts,
    notifications,
    pushTokens,
    requests,
  ] = exportResults;

  const payload = {
    export_metadata: {
      request_id: request.id,
      profile_id: profileId,
      generated_at: now().toISOString(),
      format_version: '1.0',
    },
    profile: profile.data ?? null,
    saved_addresses: savedAddresses.data ?? [],
    business_memberships: businessMemberships.data ?? [],
    driver_documents: driverDocuments.data ?? [],
    jobs: jobs.data ?? [],
    payments: payments.data ?? [],
    ratings: ratings.data ?? [],
    disputes: disputes.data ?? [],
    support_tickets: supportTickets.data ?? [],
    support_ticket_messages: supportMessages.data ?? [],
    chat_messages: chatMessages.data ?? [],
    consent_records: consentRecords.data ?? [],
    wallet_transactions: (walletTransactions.data ?? []).map((row) => {
      const transaction = { ...(row as Record<string, unknown>) };
      delete transaction.wallets;
      return transaction;
    }),
    payouts: payouts.data ?? [],
    notification_log: notifications.data ?? [],
    push_tokens: pushTokens.data ?? [],
    data_subject_requests: requests.data ?? [],
  };

  const files: Record<string, Uint8Array> = {};
  for (const [key, value] of Object.entries(payload)) {
    files[exportFileName(key)] = strToU8(JSON.stringify(value, null, 2));
  }
  const archive = zipSync(files, { level: 6 });
  const archiveBuffer = archive.buffer.slice(
    archive.byteOffset,
    archive.byteOffset + archive.byteLength,
  ) as ArrayBuffer;
  const objectPath = `${profileId}/export-${request.id}-${now().getTime()}.zip`;

  const { error: uploadError } = await service.storage
    .from('data-exports')
    .upload(objectPath, new Blob([archiveBuffer], { type: 'application/zip' }), {
      contentType: 'application/zip',
      upsert: true,
    });
  if (uploadError) throw uploadError;

  const expiresInSeconds = 7 * 24 * 60 * 60;
  const { data: signed, error: signedError } = await service.storage
    .from('data-exports')
    .createSignedUrl(objectPath, expiresInSeconds);
  if (signedError || !signed?.signedUrl) {
    throw signedError ?? new NotFoundError('Unable to create export download URL');
  }

  const completedAt = now().toISOString();
  const { error: updateError } = await service
    .from('data_subject_requests')
    .update({
      status: 'completed',
      completed_at: completedAt,
      delivered_file_path: objectPath,
    })
    .eq('id', request.id);
  if (updateError) throw updateError;

  return success({
    request_id: request.id,
    download_url: publicDownloadUrl(signed.signedUrl),
    expires_at: new Date(now().getTime() + expiresInSeconds * 1_000).toISOString(),
  });
}
