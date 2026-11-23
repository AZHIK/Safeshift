import { randomUUID } from 'node:crypto';

import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ConfirmSubmit } from '@/components/confirm-submit';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney, titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { tone } from '@/lib/money/money';
import { createClient } from '@/lib/supabase/server';

import { RecordActions } from '@/components/record-actions';
import {
  holdPayoutAction,
  payAllPendingAction,
  payPayoutAction,
  releasePayoutAction,
  retryPayoutAction,
} from '../actions';

export const dynamic = 'force-dynamic';

type Payout = {
  id: string;
  driver_id: string;
  gross_earnings: number;
  commission_deducted: number;
  withholding_tax: number;
  net_amount: number;
  currency_code: string;
  status: string;
  provider_reference: string | null;
  failure_reason: string | null;
  hold_reason: string | null;
  completed_at: string | null;
};

export default async function PayoutBatchPage({
  params,
  searchParams,
}: {
  params: Promise<{ batchId: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('payouts');
  const [{ batchId }, query] = await Promise.all([params, searchParams]);
  const supabase = await createClient();

  const [{ data: batch, error }, { data: payoutRows, error: payoutError }] = await Promise.all([
    supabase
      .from('payout_batches')
      .select('id, period_start, period_end, status, total_amount, currency_code, driver_count, failure_reason, countries(name)')
      .eq('id', batchId)
      .maybeSingle(),
    supabase
      .from('payouts')
      .select(
        'id, driver_id, gross_earnings, commission_deducted, withholding_tax, net_amount, currency_code, status, provider_reference, failure_reason, hold_reason, completed_at',
      )
      .eq('batch_id', batchId)
      .order('net_amount', { ascending: false }),
  ]);
  if (error) {
    return (
      <>
        <PageHeader title="Payout batch" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!batch) notFound();

  const payouts = (payoutRows ?? []) as Payout[];
  const driverIds = [...new Set(payouts.map((p) => p.driver_id))];
  const { data: people } = driverIds.length
    ? await supabase.from('profiles').select('id, full_name, display_name, phone').in('id', driverIds)
    : { data: [] };
  const names = new Map(
    ((people ?? []) as { id: string; full_name: string | null; display_name: string | null; phone: string | null }[]).map(
      (p) => [p.id, { name: p.full_name || p.display_name || 'Driver', phone: p.phone }],
    ),
  );

  const counts = payouts.reduce<Record<string, number>>((acc, p) => ({ ...acc, [p.status]: (acc[p.status] ?? 0) + 1 }), {});
  const pendingTotal = payouts.filter((p) => p.status === 'pending').reduce((s, p) => s + Number(p.net_amount), 0);
  const country = (batch.countries as unknown as { name?: string } | null)?.name ?? '';
  const lastDay = new Date(new Date(batch.period_end).getTime() - 1).toISOString();

  return (
    <>
      <PageHeader
        title={`Payouts ${formatDate(batch.period_start)} – ${formatDate(lastDay)}`}
        description={`${country} · ${batch.driver_count} drivers · ${formatMoney(batch.total_amount, batch.currency_code)}`}
        actions={
          <>
            <Link className="btn" href="/payouts">
              All batches
            </Link>
            <RecordActions table="payout_batches" id={batch.id} label="Batch actions" />
            {counts.pending ? (
              <form action={payAllPendingAction}>
                <input type="hidden" name="batch_id" value={batch.id} />
                <input type="hidden" name="idempotency_key" value={`batch-${randomUUID()}`} />
                <ConfirmSubmit
                  className="btn btn-primary"
                  message={`Send ${counts.pending} pending payouts (${formatMoney(pendingTotal, batch.currency_code)}) now?`}
                >
                  Pay all pending ({counts.pending})
                </ConfirmSubmit>
              </form>
            ) : null}
          </>
        }
      />
      <Notice searchParams={query} />
      {payoutError ? <div className="notice notice-error">{payoutError.message}</div> : null}
      {batch.failure_reason ? <div className="notice notice-error">{batch.failure_reason}</div> : null}

      <div className="chip-list" style={{ marginBottom: 12 }}>
        <span className={`badge badge-${tone(batch.status)}`}>Batch {titleize(batch.status)}</span>
        {Object.entries(counts).map(([status, n]) => (
          <span key={status} className={`badge badge-${tone(status)}`}>
            {n} {titleize(status)}
          </span>
        ))}
      </div>

      <div className="card">
        <DataTable
          columns={['Driver', 'Gross', 'Commission', 'Tax', 'Net', 'Status']}
          empty="This batch has no payouts."
          actions={payouts.map((p) => {
            const who = names.get(p.driver_id);
            const fields = { batch_id: batch.id, payout_id: p.id };
            return (
              <RecordActions
                key={p.id}
                table="payouts"
                id={p.id}
                label={`Actions for ${who?.name ?? 'payout'}`}
                items={[
                  ...(p.status === 'pending'
                    ? [
                        {
                          kind: 'form' as const,
                          label: 'Pay',
                          action: payPayoutAction,
                          fields: { ...fields, idempotency_key: `payout-${randomUUID()}` },
                          confirm: `Send ${formatMoney(p.net_amount, p.currency_code)} to ${who?.name ?? 'this driver'}?`,
                        },
                        { kind: 'form' as const, label: 'Hold', action: holdPayoutAction, fields, reason: 'Reason to hold' },
                      ]
                    : []),
                  ...(p.status === 'on_hold' ? [{ kind: 'form' as const, label: 'Release', action: releasePayoutAction, fields }] : []),
                  ...(p.status === 'failed' ? [{ kind: 'form' as const, label: 'Retry', action: retryPayoutAction, fields }] : []),
                  { kind: 'link' as const, label: 'Open driver', href: `/drivers/${p.driver_id}` },
                ]}
              />
            );
          })}
          rows={payouts.map((p) => {
            const who = names.get(p.driver_id);
            return [
              <div key="d">
                {who?.name ?? 'Driver'}
                <div className="small muted">{who?.phone ?? 'no phone on file'}</div>
              </div>,
              formatMoney(p.gross_earnings, p.currency_code),
              formatMoney(p.commission_deducted, p.currency_code),
              formatMoney(p.withholding_tax, p.currency_code),
              <strong key="n">{formatMoney(p.net_amount, p.currency_code)}</strong>,
              <div key="s">
                <span className={`badge badge-${tone(p.status)}`}>{titleize(p.status)}</span>
                {p.hold_reason ? <div className="small muted">{p.hold_reason}</div> : null}
                {p.failure_reason ? <div className="small muted">{p.failure_reason}</div> : null}
                {p.provider_reference ? <div className="small muted mono">{p.provider_reference}</div> : null}
              </div>,
            ];
          })}
        />
      </div>
    </>
  );
}
