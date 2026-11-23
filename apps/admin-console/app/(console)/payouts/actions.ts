'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireArea } from '@/lib/guard';
import { edgeErrorMessage } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KEY_RE = /^[A-Za-z0-9:_-]{8,128}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
/** Upper bound for one "pay all" request so it cannot run unbounded. */
const PAY_ALL_LIMIT = 100;

function go(path: string, kind: 'ok' | 'error', message: string): never {
  redirect(`${path}?${kind}=${encodeURIComponent(message)}`);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

function backTo(formData: FormData): string {
  const batchId = field(formData, 'batch_id');
  return UUID_RE.test(batchId) ? `/payouts/${batchId}` : '/payouts';
}

/** Builds a draft batch of driver payouts for a country and period (dates inclusive). */
export async function createPayoutBatchAction(formData: FormData) {
  await requireArea('payouts');
  const countryId = field(formData, 'country_id');
  const from = field(formData, 'period_start');
  const to = field(formData, 'period_end');
  if (!UUID_RE.test(countryId)) go('/payouts', 'error', 'Choose a country.');
  if (!DATE_RE.test(from) || !DATE_RE.test(to)) go('/payouts', 'error', 'Choose the start and end dates.');
  // The end date is inclusive: the period runs to midnight after it (UTC).
  const start = new Date(`${from}T00:00:00Z`);
  const end = new Date(`${to}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + 1);
  if (end <= start) go('/payouts', 'error', 'The end date must be on or after the start date.');
  if (end.getTime() > Date.now() + 24 * 3600 * 1000) {
    go('/payouts', 'error', 'A payout period cannot end in the future.');
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_payout_batch', {
    p_country_id: countryId,
    p_period_start: start.toISOString(),
    p_period_end: end.toISOString(),
  });
  if (error) {
    const message = /payout_batches_country_period_key|duplicate key/.test(error.message)
      ? 'A batch for this country and period already exists.'
      : error.message;
    go('/payouts', 'error', message);
  }
  revalidatePath('/payouts', 'layout');
  go(`/payouts/${String(data)}`, 'ok', 'Batch created. Review the payouts, then pay them.');
}

async function send(payoutId: string, idempotencyKey: string): Promise<string | null> {
  const supabase = await createClient();
  const { error } = await supabase.functions.invoke('payout-execute', {
    body: { payout_id: payoutId },
    headers: { 'x-idempotency-key': idempotencyKey },
  });
  return error ? edgeErrorMessage(error) : null;
}

/** Sends one payout to the driver through the payout-execute function. */
export async function payPayoutAction(formData: FormData) {
  await requireArea('payouts');
  const back = backTo(formData);
  const payoutId = field(formData, 'payout_id');
  const key = field(formData, 'idempotency_key');
  if (!UUID_RE.test(payoutId)) go(back, 'error', 'Missing or invalid payout.');
  if (!KEY_RE.test(key)) go(back, 'error', 'The form expired. Reload the page and try again.');

  const problem = await send(payoutId, key);
  revalidatePath('/payouts', 'layout');
  if (problem) go(back, 'error', `Payout not sent: ${problem}`);
  go(back, 'ok', 'Payout sent.');
}

/** Sends every pending payout of a batch, one by one, and reports the outcome. */
export async function payAllPendingAction(formData: FormData) {
  await requireArea('payouts');
  const back = backTo(formData);
  const batchId = field(formData, 'batch_id');
  const nonce = field(formData, 'idempotency_key');
  if (!UUID_RE.test(batchId)) go('/payouts', 'error', 'Missing or invalid batch.');
  if (!KEY_RE.test(nonce)) go(back, 'error', 'The form expired. Reload the page and try again.');

  const supabase = await createClient();
  const { data, error } = await supabase
    .from('payouts')
    .select('id')
    .eq('batch_id', batchId)
    .eq('status', 'pending')
    .order('net_amount', { ascending: false })
    .limit(PAY_ALL_LIMIT);
  if (error) go(back, 'error', error.message);
  const pending = (data ?? []) as { id: string }[];
  if (pending.length === 0) go(back, 'ok', 'No pending payouts to send.');

  let sent = 0;
  const failures: string[] = [];
  for (const payout of pending) {
    // One key per payout per click: a refresh-resubmit cannot pay twice.
    const problem = await send(payout.id, `${nonce}:${payout.id.slice(0, 8)}`);
    if (problem) failures.push(problem);
    else sent += 1;
  }
  revalidatePath('/payouts', 'layout');
  if (failures.length === 0) go(back, 'ok', `Sent ${sent} payout${sent === 1 ? '' : 's'}.`);
  go(
    back,
    'error',
    `Sent ${sent}, ${failures.length} failed. First error: ${failures[0]}. Failed payouts can be retried.`,
  );
}

async function rpcAction(formData: FormData, name: string, args: Record<string, unknown>, ok: string) {
  await requireArea('payouts');
  const back = backTo(formData);
  const supabase = await createClient();
  const { error } = await supabase.rpc(name, args);
  if (error) go(back, 'error', error.message);
  revalidatePath('/payouts', 'layout');
  go(back, 'ok', ok);
}

/** Holds a pending payout so it cannot be sent until released. */
export async function holdPayoutAction(formData: FormData) {
  const payoutId = field(formData, 'payout_id');
  const reason = field(formData, 'reason');
  if (!UUID_RE.test(payoutId)) go(backTo(formData), 'error', 'Missing or invalid payout.');
  if (reason.length < 3) go(backTo(formData), 'error', 'Give a reason for holding this payout.');
  await rpcAction(formData, 'admin_hold_payout', { p_payout_id: payoutId, p_reason: reason }, 'Payout held.');
}

export async function releasePayoutAction(formData: FormData) {
  const payoutId = field(formData, 'payout_id');
  if (!UUID_RE.test(payoutId)) go(backTo(formData), 'error', 'Missing or invalid payout.');
  await rpcAction(formData, 'admin_release_payout', { p_payout_id: payoutId }, 'Payout released. It can be paid now.');
}

export async function retryPayoutAction(formData: FormData) {
  const payoutId = field(formData, 'payout_id');
  if (!UUID_RE.test(payoutId)) go(backTo(formData), 'error', 'Missing or invalid payout.');
  await rpcAction(formData, 'admin_retry_payout', { p_payout_id: payoutId }, 'Payout reset to pending. Send it again.');
}
