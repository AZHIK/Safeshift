'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireArea } from '@/lib/guard';
import { edgeErrorMessage, refundableAmount, validateRefund, type RefundRow } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KEY_RE = /^[A-Za-z0-9:_-]{8,128}$/;

function go(path: string, kind: 'ok' | 'error', message: string): never {
  redirect(`${path}?${kind}=${encodeURIComponent(message)}`);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

/** Issues a refund through the payment-refund function (provider + ledger). */
export async function refundPaymentAction(formData: FormData) {
  await requireArea('payments');
  const paymentId = field(formData, 'payment_id');
  if (!UUID_RE.test(paymentId)) go('/payments', 'error', 'Missing or invalid payment.');
  const back = `/payments/${paymentId}`;

  // One key per rendered form: a double submit replays instead of refunding twice.
  const idempotencyKey = field(formData, 'idempotency_key');
  if (!KEY_RE.test(idempotencyKey)) go(back, 'error', 'The form expired. Reload the page and try again.');

  const input = {
    amount: Number(field(formData, 'amount')),
    reason: field(formData, 'reason'),
    refund_type: (field(formData, 'refund_type') === 'full' ? 'full' : 'partial') as 'full' | 'partial',
  };

  const supabase = await createClient();
  const [{ data: payment }, { data: refunds, error: refundsError }] = await Promise.all([
    supabase.from('payments').select('amount, payment_type, provider_status').eq('id', paymentId).maybeSingle(),
    supabase.rpc('admin_payment_refunds', { p_payment_id: paymentId }),
  ]);
  if (refundsError) go(back, 'error', refundsError.message);
  if (!payment) go(back, 'error', 'Payment not found.');
  if (payment.payment_type !== 'charge' || payment.provider_status !== 'succeeded') {
    go(back, 'error', 'Only succeeded charges can be refunded.');
  }

  const refundable = refundableAmount(payment.amount, (refunds ?? []) as RefundRow[]);
  const problem = validateRefund(input, refundable);
  if (problem) go(back, 'error', problem);

  const { data, error } = await supabase.functions.invoke('payment-refund', {
    body: { payment_id: paymentId, amount: input.amount, reason: input.reason, refund_type: input.refund_type },
    headers: { 'x-idempotency-key': idempotencyKey },
  });
  if (error) go(back, 'error', `Refund not sent: ${await edgeErrorMessage(error)}`);

  revalidatePath('/payments', 'layout');
  const status = (data as { data?: { status?: string } } | null)?.data?.status;
  go(
    back,
    'ok',
    status === 'succeeded'
      ? 'Refund paid out.'
      : 'Refund accepted by the provider and processing. It completes when the provider confirms.',
  );
}

/** Marks a processing refund paid (e.g. sent by hand), with its reference. */
export async function completeRefundAction(formData: FormData) {
  await requireArea('payments');
  const paymentId = field(formData, 'payment_id');
  const refundId = field(formData, 'refund_id');
  const back = UUID_RE.test(paymentId) ? `/payments/${paymentId}` : '/payments';
  if (!UUID_RE.test(refundId)) go(back, 'error', 'Missing or invalid refund.');
  const reference = field(formData, 'reference');
  if (reference.length < 3) go(back, 'error', 'Enter the transfer reference that proves the refund was paid.');

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_complete_refund', { p_refund_id: refundId, p_reference: reference });
  if (error) go(back, 'error', error.message);
  revalidatePath('/payments', 'layout');
  go(back, 'ok', 'Refund marked as paid.');
}

/** Gives up on a processing refund: clawbacks are returned and the job restored. */
export async function failRefundAction(formData: FormData) {
  await requireArea('payments');
  const paymentId = field(formData, 'payment_id');
  const refundId = field(formData, 'refund_id');
  const back = UUID_RE.test(paymentId) ? `/payments/${paymentId}` : '/payments';
  if (!UUID_RE.test(refundId)) go(back, 'error', 'Missing or invalid refund.');
  const reason = field(formData, 'reason');
  if (reason.length < 3) go(back, 'error', 'Give a reason of at least 3 characters.');

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_fail_refund', { p_refund_id: refundId, p_reason: reason });
  if (error) go(back, 'error', error.message);
  revalidatePath('/payments', 'layout');
  go(back, 'ok', 'Refund cancelled. The driver and platform clawbacks were returned.');
}
