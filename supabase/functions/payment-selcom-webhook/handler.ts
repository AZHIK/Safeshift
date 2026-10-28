import { verifyWebhookSignature } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { UnauthorizedError, ValidationError } from '../_shared/errors.ts';
import { readOptionalSecret } from '../_shared/vault.ts';
import {
  findPaymentByReference,
  findRefundByReference,
  insertWebhook,
  markWebhook,
  parseSelcomWebhook,
} from '../_shared/webhooks.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface SelcomWebhookDeps {
  service?: SupabaseClient;
  provider?: { id: string; webhook_secret_reference: string | null };
  secret?: string;
  verify?: (req: Request, rawBody: string, secret: string) => Promise<boolean>;
  completePayment?: (
    paymentId: string,
    providerReference: string,
    status: 'succeeded' | 'failed' | 'cancelled',
  ) => Promise<void>;
  insertEvent?: typeof insertWebhook;
  findPayment?: typeof findPaymentByReference;
  findRefund?: typeof findRefundByReference;
  markEvent?: typeof markWebhook;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: SelcomWebhookDeps = {},
): Promise<Response> {
  const service = deps.service ?? serviceClient();
  const rawBody = await req.text();

  let provider = deps.provider ?? null;
  if (!provider) {
    const { data, error: providerError } = await service
      .from('payment_providers')
      .select('id, webhook_secret_reference')
      .eq('code', 'selcom')
      .eq('is_active', true)
      .limit(1)
      .maybeSingle();
    if (providerError) throw providerError;
    provider = data as { id: string; webhook_secret_reference: string | null } | null;
  }
  if (!provider) throw new ValidationError('Selcom provider is not configured');

  const secret = deps.secret ??
    (await readOptionalSecret('SELCOM_WEBHOOK_SECRET', service)) ??
    (provider.webhook_secret_reference
      ? await readOptionalSecret(provider.webhook_secret_reference, service)
      : null);
  if (!secret) throw new UnauthorizedError('Selcom webhook secret is not configured');

  const valid = deps.verify
    ? await deps.verify(req, rawBody, secret)
    : await verifyWebhookSignature(req, 'selcom', secret, rawBody);
  if (!valid) throw new UnauthorizedError('Invalid Selcom webhook signature');

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    throw new ValidationError('Webhook body must be valid JSON');
  }

  const event = parseSelcomWebhook(payload);
  const signatureHeader = req.headers.get('x-selcom-signature') ??
    req.headers.get('x-signature') ??
    req.headers.get('x-webhook-signature');

  const insertEvent = deps.insertEvent ?? insertWebhook;
  const findPayment = deps.findPayment ?? findPaymentByReference;
  const findRefund = deps.findRefund ?? findRefundByReference;
  const markEvent = deps.markEvent ?? markWebhook;

  const inserted = await insertEvent(service, {
    providerId: provider.id,
    eventType: event.eventType,
    eventId: event.eventId,
    providerReference: event.providerReference,
    payload,
    signatureHeader,
  });
  if (inserted.duplicate) return success({ duplicate: true });

  try {
    if (!event.providerReference) {
      await markEvent(service, inserted.id, 'ignored', 'missing_provider_reference');
      return success({ ignored: true, reason: 'missing_provider_reference' });
    }

    if (event.eventType.toLowerCase().includes('refund')) {
      const refund = await findRefund(service, event.providerReference);
      if (!refund) {
        await markEvent(service, inserted.id, 'ignored', 'refund_not_found');
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
      await markEvent(service, inserted.id, 'processed');
      return success({ refund_id: refund.id, status });
    }

    const payment = await findPayment(service, event.providerReference);
    if (!payment) {
      await markEvent(service, inserted.id, 'ignored', 'payment_not_found');
      return success({ ignored: true, reason: 'payment_not_found' });
    }

    if (event.status === 'pending') {
      await markEvent(service, inserted.id, 'ignored', 'non_terminal_event');
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

    await markEvent(service, inserted.id, 'processed');
    return success({ payment_id: payment.id, status: event.status });
  } catch (error) {
    await markEvent(
      service,
      inserted.id,
      'error',
      error instanceof Error ? error.message.slice(0, 2_000) : 'processing_failed',
    ).catch(() => undefined);
    throw error;
  }
}
