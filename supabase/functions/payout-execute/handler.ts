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
import { parseJsonBody, payoutSchema } from '../_shared/validation.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface PayoutExecuteDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  userClient?: (jwt: string) => SupabaseClient;
  idempotency?: IdempotencyStore;
  transfer?: (
    providerCode: string,
    amount: number,
    currency: string,
    phone: string,
    reference: string,
  ) => Promise<{ provider_reference: string; status: 'pending' | 'succeeded' | 'failed' }>;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: PayoutExecuteDeps = {},
): Promise<Response> {
  const auth = await requireAdmin(req, 'process_payouts', deps.auth ?? defaultAuthDeps());
  const body = await parseJsonBody(req, payoutSchema);
  const idempotencyKey = getIdempotencyKey(req);
  if (!idempotencyKey) throw new ValidationError('X-Idempotency-Key header is required');

  const service = deps.service ?? serviceClient();
  const store = deps.idempotency ?? new SupabaseIdempotencyStore(service);
  const scope = 'payout-execute';
  const cached = await checkIdempotencyKey(idempotencyKey, scope, store);
  if (cached) return success(cached.response);

  const { data: payout, error: payoutError } = await service
    .from('payouts')
    .select(
      'id, driver_id, net_amount, currency_code, status, payment_provider_id, provider_reference',
    )
    .eq('id', body.payout_id)
    .maybeSingle();
  if (payoutError) throw payoutError;
  if (!payout) throw new NotFoundError('Payout not found');
  if (payout.status === 'completed') {
    return success({
      payout_id: payout.id,
      status: 'completed',
      provider_reference: payout.provider_reference,
    });
  }
  if (['failed', 'cancelled'].includes(payout.status)) {
    throw new ValidationError(`Payout is ${payout.status}`);
  }

  let providerCode = body.provider_code ?? null;
  if (!providerCode && payout.payment_provider_id) {
    const { data: provider, error: providerError } = await service
      .from('payment_providers')
      .select('code')
      .eq('id', payout.payment_provider_id)
      .maybeSingle();
    if (providerError) throw providerError;
    providerCode = provider?.code ?? null;
  }
  if (!providerCode) throw new ValidationError('Payout has no payment provider');

  const { data: profile, error: profileError } = await service
    .from('profiles')
    .select('phone')
    .eq('id', payout.driver_id)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile?.phone) throw new ValidationError('Driver has no payout phone number');

  let providerAccepted = false;
  try {
    const result = deps.transfer
      ? await deps.transfer(
        providerCode,
        Number(payout.net_amount),
        payout.currency_code,
        profile.phone,
        `payout:${payout.id}`,
      )
      : providerCode === 'selcom'
      ? await (await selcomClient(ctx.requestId)).initiatePayout(
        Number(payout.net_amount),
        payout.currency_code,
        profile.phone,
        `payout:${payout.id}`,
        'SafeShift driver payout',
      )
      : providerCode === 'flutterwave'
      ? await (await flutterwaveClient(ctx.requestId)).initiateTransfer(
        Number(payout.net_amount),
        payout.currency_code,
        profile.phone,
        `payout:${payout.id}`,
        'SafeShift driver payout',
      )
      : (() => {
        throw new ValidationError(`Payouts are not implemented for ${providerCode}`);
      })();

    providerAccepted = result.status !== 'failed';
    const { error: processingError } = await service
      .from('payouts')
      .update({
        status: result.status === 'failed' ? 'failed' : 'processing',
        provider_reference: result.provider_reference,
        failure_reason: result.status === 'failed' ? 'provider transfer failed' : null,
      })
      .eq('id', payout.id);
    if (processingError) throw processingError;

    if (result.status === 'failed') {
      throw new ValidationError('Provider rejected the payout');
    }

    const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);
    const { error: executeError } = await client.rpc('execute_payout', { p_payout_id: payout.id });
    if (executeError) throw executeError;

    const response = {
      payout_id: payout.id,
      status: 'completed',
      provider_reference: result.provider_reference,
    };
    await storeIdempotencyKey(
      idempotencyKey,
      scope,
      response,
      await hashRequest(body),
      store,
    );
    return success(response);
  } catch (error) {
    if (!providerAccepted) {
      await service
        .from('payouts')
        .update({
          status: 'failed',
          failure_reason: error instanceof Error
            ? error.message.slice(0, 1_000)
            : 'provider_payout_failed',
        })
        .eq('id', payout.id)
        .then(() => undefined, () => undefined);
    }
    await recordDeadLetter(
      'payout-execute',
      { payout_id: payout.id },
      error,
      4,
      service,
    );
    throw error;
  }
}
