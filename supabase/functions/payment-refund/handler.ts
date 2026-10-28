import { type AuthDeps, defaultAuthDeps, requireAdmin } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient, userClient } from '../_shared/db.ts';
import { recordDeadLetter } from '../_shared/dead_letter.ts';
import { NotFoundError, ValidationError } from '../_shared/errors.ts';
import {
  checkIdempotencyKey,
  getIdempotencyKey,
  hashRequest,
  type IdempotencyStore,
  storeIdempotencyKey,
  SupabaseIdempotencyStore,
} from '../_shared/idempotency.ts';
import { flutterwaveClient, selcomClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, refundSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';
import type { RefundResult } from '../_shared/types/index.ts';

export interface PaymentRefundDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  userClient?: (jwt: string) => SupabaseClient;
  idempotency?: IdempotencyStore;
  refundProvider?: (
    providerCode: string,
    providerReference: string,
    amount: number,
    reason: string,
  ) => Promise<RefundResult>;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: PaymentRefundDeps = {},
): Promise<Response> {
  const auth = await requireAdmin(req, 'process_refunds', deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, refundSchema);
  const idempotencyKey = getIdempotencyKey(req);
  if (!idempotencyKey) throw new ValidationError('X-Idempotency-Key header is required');

  const service = deps.service ?? serviceClient();
  const store = deps.idempotency ?? new SupabaseIdempotencyStore(service);
  const scope = 'payment-refund';
  const cached = await checkIdempotencyKey(idempotencyKey, scope, store);
  if (cached) return success(cached.response);

  const { data: original, error: paymentError } = await service
    .from('payments')
    .select(
      'id, provider_id, provider_reference, amount, currency_code, payment_type, provider_status',
    )
    .eq('id', body.payment_id)
    .maybeSingle();
  if (paymentError) throw paymentError;
  if (!original) throw new NotFoundError('Payment not found');
  if (original.payment_type !== 'charge' || original.provider_status !== 'succeeded') {
    throw new ValidationError('Only succeeded charges can be refunded');
  }

  const { data: provider, error: providerError } = await service
    .from('payment_providers')
    .select('code, supports_refunds')
    .eq('id', original.provider_id)
    .maybeSingle();
  if (providerError) throw providerError;
  if (!provider) throw new NotFoundError('Payment provider not found');
  if (!provider.supports_refunds) throw new ValidationError('Provider does not support refunds');

  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);
  const { data: refundPaymentId, error: refundError } = await client.rpc('payment_refund', {
    p_payment_id: body.payment_id,
    p_refund_amount: body.amount,
    p_refund_type: body.refund_type,
    p_reason: body.reason,
  });
  if (refundError) throw refundError;

  const { data: refund, error: rowError } = await service
    .from('refunds')
    .select('id, provider_reference, status')
    .eq('refund_payment_id', refundPaymentId)
    .maybeSingle();
  if (rowError) throw rowError;
  if (!refund) throw new NotFoundError('Refund row not found');

  try {
    const result = deps.refundProvider
      ? await deps.refundProvider(
        provider.code,
        original.provider_reference,
        body.amount,
        body.reason,
      )
      : provider.code === 'selcom'
      ? await (await selcomClient(ctx.requestId)).refundPayment(
        original.provider_reference,
        body.amount,
        body.reason,
      )
      : provider.code === 'flutterwave'
      ? await (await flutterwaveClient(ctx.requestId)).refundPayment(
        original.provider_reference,
        body.amount,
        body.reason,
      )
      : (() => {
        throw new ValidationError(`Refunds are not implemented for ${provider.code}`);
      })();

    const finalStatus = result.status === 'succeeded' ? 'succeeded' : 'pending';
    const { error: refundUpdateError } = await service
      .from('refunds')
      .update({
        provider_reference: result.refund_reference,
        status: finalStatus,
        completed_at: finalStatus === 'succeeded' ? new Date().toISOString() : null,
      })
      .eq('id', refund.id);
    if (refundUpdateError) throw refundUpdateError;

    const response = {
      refund_id: refund.id,
      refund_payment_id: refundPaymentId,
      status: finalStatus,
      provider_reference: result.refund_reference,
    };
    await storeIdempotencyKey(
      idempotencyKey,
      scope,
      response,
      await hashRequest(body),
      store,
    );
    return success(response, 201);
  } catch (error) {
    await service
      .from('refunds')
      .update({
        status: 'failed',
        failure_reason: error instanceof Error
          ? error.message.slice(0, 1_000)
          : 'provider_refund_failed',
      })
      .eq('id', refund.id)
      .then(() => undefined, () => undefined);
    await recordDeadLetter(
      'payment-refund',
      { refund_id: refund.id, payment_id: body.payment_id },
      error,
      4,
      service,
    );
    throw error;
  }
}
