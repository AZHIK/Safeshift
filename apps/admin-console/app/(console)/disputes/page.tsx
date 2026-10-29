import { updateDisputeAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const statuses = ['open', 'in_review', 'escalated', 'resolved_customer', 'resolved_driver', 'resolved_split', 'dismissed'];

export default async function DisputesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('disputes');
  const params = await searchParams;
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('disputes')
    .select('id, job_id, raised_by, raised_by_role, dispute_type, status, priority, summary, requested_resolution, resolution_notes, created_at, dispute_messages(id), dispute_attachments(id)')
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <>
      <PageHeader title="Disputes" description="Damage, loss, delay, fare, no-show, and safety cases visible to both parties and staff." />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Case', 'Job', 'Raised by', 'Type', 'Status', 'Priority', 'Evidence', 'Decision']}
          rows={(data ?? []).map((dispute) => [
            <div key="c">
              <span className="mono">{shortId(dispute.id)}</span>
              <div className="small muted">{formatDate(dispute.created_at)}</div>
            </div>,
            <span className="mono small" key="j">{shortId(dispute.job_id)}</span>,
            <div className="small" key="r">{titleize(dispute.raised_by_role)}<div className="mono muted">{shortId(dispute.raised_by)}</div></div>,
            <div key="t">{titleize(dispute.dispute_type)}<div className="small muted" style={{ maxWidth: 260 }}>{dispute.summary}</div></div>,
            <StatusBadge key="s" value={dispute.status} />,
            <StatusBadge key="p" value={dispute.priority} />,
            <span className="small" key="e">{dispute.dispute_messages?.length ?? 0} msgs<br />{dispute.dispute_attachments?.length ?? 0} files</span>,
            <form action={updateDisputeAction} className="form" style={{ minWidth: 230, gap: 5 }} key="a">
              <input type="hidden" name="dispute_id" value={dispute.id} />
              <select className="input" name="status" defaultValue={dispute.status}>
                {statuses.map((value) => <option value={value} key={value}>{titleize(value)}</option>)}
              </select>
              <select className="input" name="priority" defaultValue={dispute.priority}>
                {['low', 'normal', 'high', 'urgent'].map((value) => <option value={value} key={value}>{titleize(value)}</option>)}
              </select>
              <input className="input" name="resolution" placeholder="Resolution notes" defaultValue={dispute.resolution_notes ?? ''} />
              <button className="btn btn-primary btn-sm" type="submit">Save</button>
            </form>,
          ])}
          empty="No disputes found."
        />
      </div>
    </>
  );
}
