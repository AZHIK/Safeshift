import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function JobsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  await requireArea('jobs');
  const params = await searchParams;
  const status = params.status ?? '';
  const supabase = await createClient();
  let query = supabase
    .from('jobs')
    .select('id, status, created_at, completed_at, final_amount, final_currency_code, customer_id, driver_id')
    .order('created_at', { ascending: false })
    .limit(100);
  if (status) query = query.eq('status', status);
  const { data, error } = await query;

  return (
    <>
      <PageHeader title="Jobs" description="Marketplace jobs across all stages. Use status filters to focus operations." />
      <form className="card card-pad form-row" method="get" style={{ marginBottom: 16 }}>
        <div className="field">
          <label htmlFor="status">Status</label>
          <select className="input" id="status" name="status" defaultValue={status}>
            <option value="">All statuses</option>
            {['requested', 'quoted', 'matched', 'accepted', 'heading_to_pickup', 'arrived', 'loading', 'in_transit', 'delivered', 'completed', 'cancelled'].map((value) => (
              <option value={value} key={value}>{titleize(value)}</option>
            ))}
          </select>
        </div>
        <button className="btn btn-primary" type="submit">Filter</button>
      </form>
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Job', 'Status', 'Customer', 'Driver', 'Fare', 'Created', 'Completed']}
          rows={(data ?? []).map((job) => [
            <span className="mono" key="j">{shortId(job.id)}</span>,
            <StatusBadge key="s" value={job.status} />,
            <span className="mono small" key="c">{shortId(job.customer_id)}</span>,
            <span className="mono small" key="d">{shortId(job.driver_id)}</span>,
            formatMoney(job.final_amount, job.final_currency_code ?? 'TZS'),
            <span className="small muted" key="cr">{formatDate(job.created_at)}</span>,
            <span className="small muted" key="co">{formatDate(job.completed_at)}</span>,
          ])}
          empty="No jobs match this filter."
        />
      </div>
    </>
  );
}
