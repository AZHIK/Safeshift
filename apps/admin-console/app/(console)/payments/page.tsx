import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function PaymentsPage() {
  await requireArea('payments');
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('payments')
    .select('id, job_id, customer_id, amount, currency_code, provider_status, payment_type, provider_reference, initiated_at, completed_at')
    .order('initiated_at', { ascending: false })
    .limit(100);

  return (
    <>
      <PageHeader title="Payments" description="Charges, refunds, provider status, and reconciliation references." />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Payment', 'Job', 'Type', 'Amount', 'Provider status', 'Reference', 'Initiated', 'Completed']}
          rows={(data ?? []).map((payment) => [
            <span className="mono" key="p">{shortId(payment.id)}</span>,
            <span className="mono small" key="j">{shortId(payment.job_id)}</span>,
            titleize(payment.payment_type),
            formatMoney(payment.amount, payment.currency_code ?? 'TZS'),
            <StatusBadge key="s" value={payment.provider_status} />,
            <span className="mono small" key="r">{payment.provider_reference ?? '—'}</span>,
            <span className="small muted" key="i">{formatDate(payment.initiated_at)}</span>,
            <span className="small muted" key="c">{formatDate(payment.completed_at)}</span>,
          ])}
          empty="No payments found."
        />
      </div>
    </>
  );
}
