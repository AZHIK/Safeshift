import { verifyWebhookSignature } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { UnauthorizedError, ValidationError } from '../_shared/errors.ts';
import { readOptionalSecret } from '../_shared/vault.ts';
import {
  findPaymentByReference,
  findPaymentByTxRef,
  findRefundByReference,
  insertWebhook,
  markWebhook,
  parseFlutterwaveWebhook,
} from '../_shared/webhooks.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface FlutterwaveWebhookDeps {
  service?: SupabaseClient;
  secret?: string;
  verify?: (req: Request, rawBody: string, secret: string) => Promise<boolean>;
  completePayment?: (
    paymentId: string,
    providerReference: string,
    status: 'succeeded' | 'failed' | 'cancelled',
  ) => Promise<void>;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: FlutterwaveWebhookDeps = {},
): Promise<Response> {
  const service = deps.service ?? serviceClient();
  const rawBody = await req.text();

  const { data: provider, error: providerError } = await service
    .from('payment_providers')
    .select('id, webhook_secret_reference')
    .eq('code', 'flutterwave')
    .eq('is_active', true)
    .limit(1)
    .maybeSingle();
  if (providerError) throw providerError;
  if (!provider) throw new ValidationError('Flutterwave provider is not configured');

  const secret = deps.secret ??
    (await readOptionalSecret('FLUTTERWAVE_WEBHOOK_SECRET', service)) ??
    (await readOptionalSecret('FLUTTERWAVE_SECRET_HASH', service)) ??
    (provider.webhook_secret_reference
      ? await readOptionalSecret(provider.webhook_secret_reference, service)
      : null);
  if (!secret) throw new UnauthorizedError('Flutterwave webhook secret is not configured');

  const valid = deps.verify
    ? await deps.verify(req, rawBody, secret)
    : await verifyWebhookSignature(req, 'flutterwave', secret, rawBody);
  if (!valid) throw new UnauthorizedError('Invalid Flutterwave webhook signature');

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    throw new ValidationError('Webhook body must be valid JSON');
  }

  const event = parseFlutterwaveWebhook(payload);
  const signatureHeader = req.headers.get('verif-hash') ??
    req.headers.get('x-flutterwave-signature');

  const inserted = await insertWebhook(service, {
    providerId: provider.id,
    eventType: event.eventType,
    eventId: event.eventId,
    providerReference: event.providerReference,
    payload,
    signatureHeader,
  });
  if (inserted.duplicate) return success({ duplicate: true });

  try {
    const data = (payload.data ?? payload) as Record<string, unknown>;
    const txRef = typeof data.tx_ref === 'string' ? data.tx_ref : null;

    if (event.eventType === 'transfer.completed' && event.providerReference) {
      const { data: payout, error } = await service
        .from('payouts')
        .select('id')
        .eq('provider_reference', event.providerReference)
        .maybeSingle();
      if (error) throw error;
      if (!payout) {
        await markWebhook(service, inserted.id, 'ignored', 'payout_not_found');
        return success({ ignored: true, reason: 'payout_not_found' });
      }
      const status = event.status === 'succeeded' ? 'completed' : 'failed';
      const { error: payoutError } = await service
        .from('payouts')
        .update({
          status,
          completed_at: status === 'completed' ? new Date().toISOString() : null,
          failure_reason: status === 'failed' ? 'provider transfer failed' : null,
        })
        .eq('id', payout.id);
      if (payoutError) throw payoutError;
      await markWebhook(service, inserted.id, 'processed');
      return success({ payout_id: payout.id, status });
    }

    if (event.eventType.includes('refund') && event.providerReference) {
      const refund = await findRefundByReference(service, event.providerReference);
      if (!refund) {
        await markWebhook(service, inserted.id, 'ignored', 'refund_not_found');
        return success({ ignored: true, reason: 'refund_not_found' });
      }
      const status = event.status === 'succeeded' ? 'succeeded' : 'failed';
      const { error: refundError } = await service
        .from('refunds')
        .update({
          status,
          completed_at: status === 'succeeded' ? new Date().toISOString() : null,
          failure_reason: status === 'failed' ? 'provider refund failed' : null,
        })
        .eq('id', refund.id);
      if (refundError) throw refundError;
      await markWebhook(service, inserted.id, 'processed');
      return success({ refund_id: refund.id, status });
    }

    if (!event.providerReference) {
      await markWebhook(service, inserted.id, 'ignored', 'missing_provider_reference');
      return success({ ignored: true, reason: 'missing_provider_reference' });
    }

    let payment = await findPaymentByReference(service, event.providerReference);
    if (!payment && txRef) payment = await findPaymentByTxRef(service, txRef);
    if (!payment) {
      await markWebhook(service, inserted.id, 'ignored', 'payment_not_found');
      return success({ ignored: true, reason: 'payment_not_found' });
    }

    if (event.status === 'pending') {
      await markWebhook(service, inserted.id, 'ignored', 'non_terminal_event');
      return success({ ignored: true, reason: 'non_terminal_event' });
    }

    if (deps.completePayment) {
      await deps.completePayment(payment.id, event.providerReference, event.status);
    } else {
      const { error } = await service.rpc('job_pay_complete', {
        p_payment_id: payment.id,
        p_provider_reference: event.providerReference,
        p_provider_status: event.status,
      });
      if (error) throw error;
    }

    await markWebhook(service, inserted.id, 'processed');
    return success({ payment_id: payment.id, status: event.status });
  } catch (error) {
    await markWebhook(
      service,
      inserted.id,
      'error',
      error instanceof Error ? error.message.slice(0, 2_000) : 'processing_failed',
    ).catch(() => undefined);
    throw error;
  }
}
