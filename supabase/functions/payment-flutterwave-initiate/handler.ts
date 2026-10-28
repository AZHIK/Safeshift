import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient, userClient } from '../_shared/db.ts';
import { recordDeadLetter } from '../_shared/dead_letter.ts';
import { ForbiddenError, NotFoundError, ValidationError } from '../_shared/errors.ts';
import {
  checkIdempotencyKey,
  getIdempotencyKey,
  hashRequest,
  type IdempotencyStore,
  storeIdempotencyKey,
  SupabaseIdempotencyStore,
} from '../_shared/idempotency.ts';
import { flutterwaveClient } from '../_shared/provider_factory.ts';
import { success } from '../_shared/response.ts';
import { parseJsonBody, paymentInitiateSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';
import type { FlutterwaveClient } from '../_shared/providers/flutterwave.ts';

export interface PaymentFlutterwaveInitiateDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  userClient?: (jwt: string) => SupabaseClient;
  provider?: FlutterwaveClient;
  idempotency?: IdempotencyStore;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: PaymentFlutterwaveInitiateDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, paymentInitiateSchema);
  if (!body.phone && !body.card_token) {
    throw new ValidationError('phone or card_token is required for Flutterwave');
  }

  const idempotencyKey = getIdempotencyKey(req);
  if (!idempotencyKey) throw new ValidationError('X-Idempotency-Key header is required');

  const service = deps.service ?? serviceClient();
  const store = deps.idempotency ?? new SupabaseIdempotencyStore(service);
  const scope = 'payment-flutterwave-initiate';
  const cached = await checkIdempotencyKey(idempotencyKey, scope, store);
  if (cached) return success(cached.response);

  const { data: job, error: jobError } = await service
    .from('jobs')
    .select('id, customer_id, status, payment_status, quote_id')
    .eq('id', body.job_id)
    .maybeSingle();

  if (jobError) throw jobError;
  if (!job) throw new NotFoundError('Job not found');
  if (job.customer_id !== auth.userId) throw new ForbiddenError('You do not own this job');
  if (!['delivered', 'completed'].includes(job.status)) {
    throw new ValidationError(`Job is not payable in status ${job.status}`);
  }
  if (job.payment_status !== 'pending') {
    throw new ValidationError(`Job payment is already ${job.payment_status}`);
  }

  const { data: quote, error: quoteError } = await service
    .from('quotes')
    .select('total, currency_code')
    .eq('id', job.quote_id)
    .maybeSingle();
  if (quoteError) throw quoteError;
  if (!quote) throw new NotFoundError('Quote not found');

  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);
  const { data: paymentId, error: initiateError } = await client.rpc('job_payment_initiate', {
    p_job_id: body.job_id,
    p_provider_code: 'flutterwave',
    p_amount: quote.total,
    p_idempotency_key: idempotencyKey,
    p_metadata: {},
    p_payment_method_id: body.payment_method_id ?? null,
  });
  if (initiateError) throw initiateError;
  if (!paymentId) throw new ValidationError('Payment initiation returned no identifier');

  try {
    const provider = deps.provider ?? await flutterwaveClient(ctx.requestId);
    const tokenOrPhone = body.card_token ? `card:${body.card_token}` : body.phone!;
    const result = await provider.initiatePayment(
      Number(quote.total),
      quote.currency_code,
      tokenOrPhone,
      `safeshift:${paymentId}`,
      'SafeShift job payment',
    );

    const { error: updateError } = await service
      .from('payments')
      .update({ provider_reference: result.provider_reference })
      .eq('id', paymentId);
    if (updateError) throw updateError;

    const response = {
      payment_id: paymentId,
      redirect_url: result.redirect_url,
      status: 'pending' as const,
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
    await service.rpc('job_pay_complete', {
      p_payment_id: paymentId,
      p_provider_reference: '',
      p_provider_status: 'failed',
    });
    await recordDeadLetter(
      'payment-flutterwave-initiate',
      { payment_id: paymentId, job_id: body.job_id },
      error,
      4,
      service,
    );
    throw error;
  }
}
