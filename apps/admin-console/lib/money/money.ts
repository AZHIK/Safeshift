// Money helpers shared by the payments and payouts pages, their actions and
// the tests. The database and the edge functions remain the authority.

export type RefundRow = { amount: number | string; status: string };

/** What can still be refunded: failed refunds returned their money. */
export function refundableAmount(chargeAmount: number | string, refunds: RefundRow[]): number {
  const used = refunds
    .filter((r) => r.status !== 'failed')
    .reduce((sum, r) => sum + Number(r.amount), 0);
  return Math.max(0, Math.round((Number(chargeAmount) - used) * 100) / 100);
}

export type RefundInput = { amount: number; reason: string; refund_type: 'full' | 'partial' };

/** Validates a refund request before it reaches the payment-refund function. */
export function validateRefund(input: RefundInput, refundable: number): string | null {
  if (!Number.isFinite(input.amount) || input.amount <= 0) return 'Enter an amount greater than 0.';
  if (Math.round(input.amount * 100) !== input.amount * 100) return 'Use at most two decimal places.';
  if (input.amount > refundable) return `At most ${refundable} can still be refunded.`;
  if (input.refund_type === 'full' && input.amount !== refundable) {
    return 'A full refund must be for the whole remaining amount.';
  }
  const reason = input.reason.trim();
  if (reason.length < 3) return 'Give a reason of at least 3 characters.';
  if (reason.length > 1000) return 'Keep the reason under 1,000 characters.';
  return null;
}

export const PAYMENT_STATUS_TONE: Record<string, string> = {
  succeeded: 'green',
  pending: 'amber',
  initiated: 'amber',
  processing: 'amber',
  requested: 'amber',
  on_hold: 'violet',
  failed: 'red',
  cancelled: 'gray',
  completed: 'green',
  draft: 'gray',
  partial: 'amber',
};

export function tone(status: string): string {
  return PAYMENT_STATUS_TONE[status] ?? 'blue';
}

type FunctionsError = {
  message?: string;
  context?: { json?: () => Promise<unknown>; text?: () => Promise<string> };
};

/**
 * Pulls the human message out of a supabase.functions.invoke error. Edge
 * functions answer { data, error: { code, message } }; the client only says
 * "Edge Function returned a non-2xx status code" unless the body is read.
 */
export async function edgeErrorMessage(error: unknown): Promise<string> {
  const e = error as FunctionsError;
  try {
    const body = (await e.context?.json?.()) as { error?: { message?: string }; message?: string } | undefined;
    const message = body?.error?.message ?? body?.message;
    if (message) return message;
  } catch {
    // Not JSON; fall through.
  }
  return e.message ?? 'The request failed.';
}
