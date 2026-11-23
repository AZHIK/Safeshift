import { randomUUID } from 'node:crypto';

import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ConfirmSubmit } from '@/components/confirm-submit';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { refundableAmount, tone, type RefundRow } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';

import { completeRefundAction, failRefundAction, refundPaymentAction } from '../actions';

export const dynamic = 'force-dynamic';

type Refund = RefundRow & {
  id: string;
  amount: number;
  currency_code: string;
  refund_type: string;
  reason: string;
  failure_reason: string | null;
  provider_reference: string | null;
  requested_by_name: string;
  created_at: string;
  completed_at: string | null;
};

export default async function PaymentDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('payments');
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const supabase = await createClient();

  const [{ data: payment, error }, { data: refundRows, error: refundError }] = await Promise.all([
    supabase
      .from('payments')
      .select(
        'id, job_id, customer_id, amount, currency_code, provider_status, payment_type, provider_reference, failure_reason, initiated_at, completed_at, payment_providers(code, supports_refunds, supports_partial_refunds)',
      )
      .eq('id', id)
      .maybeSingle(),
    supabase.rpc('admin_payment_refunds', { p_payment_id: id }),
  ]);
  if (error) {
    return (
      <>
        <PageHeader title="Payment" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!payment) notFound();

  const provider = payment.payment_providers as unknown as {
    code?: string;
    supports_refunds?: boolean;
    supports_partial_refunds?: boolean;
  } | null;
  const refunds = (refundRows ?? []) as Refund[];
  const refundable = refundableAmount(payment.amount, refunds);
  const canRefund =
    payment.payment_type === 'charge' && payment.provider_status === 'succeeded' && provider?.supports_refunds && refundable > 0;
  const currency = payment.currency_code;

  return (
    <>
      <PageHeader
        title={`Payment ${shortId(payment.id)}`}
        description={`${titleize(payment.payment_type)} · ${formatMoney(payment.amount, currency)} · ${provider?.code ?? 'unknown provider'}`}
        actions={
          <Link className="btn" href="/payments">
            All payments
          </Link>
        }
      />
      <Notice searchParams={query} />
      {refundError ? <div className="notice notice-error">{refundError.message}</div> : null}

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <div className="metric">
          <div className="metric-label">Status</div>
          <div className="metric-value">
            <span className={`badge badge-${tone(payment.provider_status)}`}>{titleize(payment.provider_status)}</span>
          </div>
          <div className="metric-note">{formatDate(payment.completed_at ?? payment.initiated_at)}</div>
        </div>
        <div className="metric">
          <div className="metric-label">Charged</div>
          <div className="metric-value">{formatMoney(payment.amount, currency)}</div>
          <div className="metric-note mono">{payment.provider_reference ?? 'no reference'}</div>
        </div>
        <div className="metric">
          <div className="metric-label">Refundable</div>
          <div className="metric-value">{formatMoney(refundable, currency)}</div>
          <div className="metric-note">{refunds.filter((r) => r.status !== 'failed').length} refunds so far</div>
        </div>
        <div className="metric">
          <div className="metric-label">Job</div>
          <div className="metric-value mono small">{shortId(payment.job_id)}</div>
        </div>
      </div>

      <div className="split">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Refunds</h2>
            <p className="card-sub">A processing refund is reserved against the charge until it completes or is cancelled.</p>
          </div>
          <DataTable
            columns={['When', 'Amount', 'Status', 'Reason', 'By', '']}
            empty="No refunds."
            rows={refunds.map((r) => [
              <span key="w" className="small nowrap">
                {formatDate(r.created_at)}
              </span>,
              <span key="a">
                {formatMoney(r.amount, r.currency_code)}
                <div className="small muted">{titleize(r.refund_type)}</div>
              </span>,
              <span key="s">
                <span className={`badge badge-${tone(r.status)}`}>{titleize(r.status)}</span>
                {r.provider_reference ? <div className="small muted mono">{r.provider_reference}</div> : null}
                {r.failure_reason ? <div className="small muted">{r.failure_reason}</div> : null}
              </span>,
              <span key="r" className="small">
                {r.reason}
              </span>,
              r.requested_by_name,
              r.status === 'processing' ? (
                <div key="x" className="section-stack">
                  <form action={completeRefundAction} className="inline">
                    <input type="hidden" name="payment_id" value={payment.id} />
                    <input type="hidden" name="refund_id" value={r.id} />
                    <input className="input input-sm" name="reference" placeholder="Transfer ref" required minLength={3}
                      aria-label="Transfer reference" />
                    <button className="btn btn-sm" type="submit">Mark paid</button>
                  </form>
                  <form action={failRefundAction} className="inline">
                    <input type="hidden" name="payment_id" value={payment.id} />
                    <input type="hidden" name="refund_id" value={r.id} />
                    <input className="input input-sm" name="reason" placeholder="Why it failed" required minLength={3}
                      aria-label="Reason the refund failed" />
                    <ConfirmSubmit className="btn btn-sm" message="Cancel this refund? Clawbacks are returned to the driver and platform.">
                      Cancel
                    </ConfirmSubmit>
                  </form>
                </div>
              ) : (
                <span key="x" />
              ),
            ])}
          />
        </div>

        <div className="card card-pad">
          <h2 className="card-title">Issue a refund</h2>
          {canRefund ? (
            <form action={refundPaymentAction} className="form" style={{ marginTop: 8 }}>
              <input type="hidden" name="payment_id" value={payment.id} />
              {/* A fresh key per rendered form: double submits cannot refund twice. */}
              <input type="hidden" name="idempotency_key" value={`refund-${randomUUID()}`} />
              <label className="field">
                Amount ({currency})
                <input className="input" name="amount" type="number" min="0.01" max={refundable} step="0.01"
                  defaultValue={refundable} required />
                <span className="small muted">Up to {formatMoney(refundable, currency)}.</span>
              </label>
              <label className="field">
                Type
                <select className="input" name="refund_type" defaultValue="partial">
                  <option value="partial">Partial</option>
                  <option value="full">Full (everything remaining)</option>
                </select>
              </label>
              {!provider?.supports_partial_refunds ? (
                <p className="small muted">This provider only refunds the full remaining amount.</p>
              ) : null}
              <label className="field">
                Reason
                <textarea className="input" name="reason" rows={3} minLength={3} maxLength={1000} required
                  placeholder="e.g. Item damaged in transit (ticket #123)" />
              </label>
              <p className="small muted">
                The driver&apos;s share and the platform commission are clawed back in proportion. If the provider rejects the
                refund, both are returned automatically.
              </p>
              <ConfirmSubmit className="btn btn-primary" message="Send this refund to the customer?">
                Refund
              </ConfirmSubmit>
            </form>
          ) : (
            <p className="small muted" style={{ marginTop: 8 }}>
              {payment.payment_type !== 'charge'
                ? 'This is a refund payment; open the original charge to refund more.'
                : payment.provider_status !== 'succeeded'
                  ? 'Only succeeded charges can be refunded.'
                  : !provider?.supports_refunds
                    ? 'This provider does not support refunds.'
                    : 'Nothing left to refund.'}
            </p>
          )}
        </div>
      </div>
    </>
  );
}
