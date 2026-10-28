import type { SupabaseClient } from './db.ts';
import { InternalError, ValidationError } from './errors.ts';

export interface NormalizedWebhook {
  eventType: string;
  eventId: string | null;
  providerReference: string | null;
  status: 'succeeded' | 'failed' | 'cancelled' | 'pending';
  amount: number | null;
  raw: Record<string, unknown>;
}

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === 'string' && value.trim().length > 0) return value.trim();
  }
  return null;
}

export function normalizePaymentStatus(raw: unknown): NormalizedWebhook['status'] {
  const value = String(raw ?? '').toLowerCase();
  if (['success', 'succeeded', 'successful', 'paid', 'completed'].includes(value)) {
    return 'succeeded';
  }
  if (['failed', 'error', 'declined'].includes(value)) return 'failed';
  if (['cancelled', 'canceled', 'voided'].includes(value)) return 'cancelled';
  return 'pending';
}

export function parseSelcomWebhook(payload: Record<string, unknown>): NormalizedWebhook {
  const data = (payload.data ?? payload) as Record<string, unknown>;
  const eventType = firstString(payload.event_type, payload.event, payload.type) ??
    'payment.updated';
  const providerReference = firstString(
    data.order_id,
    data.provider_reference,
    data.reference,
    payload.order_id,
    payload.reference,
  );
  const status = normalizePaymentStatus(data.status ?? data.payment_status ?? payload.status);
  return {
    eventType,
    // Selcom does not always send an event id. Include the status so a pending
    // event and the later terminal event for the same order are not deduped.
    eventId: firstString(payload.event_id, payload.id, data.event_id) ??
      `${eventType}:${providerReference ?? 'unknown'}:${status}`,
    providerReference,
    status,
    amount: Number(data.amount ?? payload.amount ?? 0) || null,
    raw: payload,
  };
}

export function parseFlutterwaveWebhook(payload: Record<string, unknown>): NormalizedWebhook {
  const data = (payload.data ?? payload) as Record<string, unknown>;
  const eventType = firstString(payload.event, payload.event_type, payload.type) ??
    'charge.completed';
  const providerReference = firstString(data.id, data.tx_ref, payload.tx_ref);
  const status = normalizePaymentStatus(data.status ?? payload.status);
  return {
    eventType,
    eventId: firstString(payload.id, payload.event_id) ??
      `${eventType}:${providerReference ?? 'unknown'}:${status}`,
    providerReference,
    status,
    amount: Number(data.amount ?? payload.amount ?? 0) || null,
    raw: payload,
  };
}

export async function insertWebhook(
  service: SupabaseClient,
  input: {
    providerId: string;
    eventType: string;
    eventId: string | null;
    providerReference: string | null;
    payload: Record<string, unknown>;
    signatureHeader: string | null;
  },
): Promise<{ id: number; duplicate: boolean }> {
  if (!input.eventId?.trim()) {
    throw new ValidationError('Webhook event id is required');
  }
  if (!input.eventType.trim()) {
    throw new ValidationError('Webhook event type is required');
  }

  const { data, error } = await service.rpc('record_payment_webhook', {
    p_provider_id: input.providerId,
    p_event_type: input.eventType,
    p_event_id: input.eventId,
    p_provider_reference: input.providerReference,
    p_payload: input.payload,
    p_signature_header: input.signatureHeader,
  });
  if (error) throw error;

  const row = (Array.isArray(data) ? data[0] : data) as
    | { webhook_id?: unknown; duplicate?: unknown }
    | null
    | undefined;
  if (!row) throw new InternalError('Webhook insert returned no row');

  return {
    id: Number(row.webhook_id ?? 0),
    duplicate: Boolean(row.duplicate),
  };
}

export async function markWebhook(
  service: SupabaseClient,
  id: number,
  status: 'processed' | 'ignored' | 'error',
  processingError?: string,
): Promise<void> {
  if (!id) return;
  const { error } = await service
    .from('payment_webhooks')
    .update({
      processing_status: status,
      processing_error: processingError ?? null,
      processed_at: new Date().toISOString(),
    })
    .eq('id', id);
  if (error) throw error;
}

export async function findPaymentByReference(
  service: SupabaseClient,
  reference: string,
): Promise<{ id: string; job_id: string; provider_status: string } | null> {
  const { data, error } = await service
    .from('payments')
    .select('id, job_id, provider_status')
    .eq('provider_reference', reference)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

export async function findPaymentByTxRef(
  service: SupabaseClient,
  txRef: string,
): Promise<{ id: string; job_id: string; provider_status: string } | null> {
  const { data, error } = await service
    .from('payments')
    .select('id, job_id, provider_status')
    .eq('metadata->>tx_ref', txRef)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

export async function findRefundByReference(
  service: SupabaseClient,
  reference: string,
): Promise<{ id: string; status: string } | null> {
  const { data, error } = await service
    .from('refunds')
    .select('id, status')
    .eq('provider_reference', reference)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}
