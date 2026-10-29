import { updateDataRequestAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function DataRequestsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('data-requests');
  const params = await searchParams;
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('data_subject_requests')
    .select('id, request_number, requester_profile_id, request_type, status, reason, requested_at, verified_at, completed_at, assigned_to, notes')
    .order('requested_at', { ascending: false })
    .limit(100);

  return (
    <>
      <PageHeader title="Data requests" description="Privacy export, deletion, rectification, and processing-restriction requests. Identity verification is required before delivery." />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Request', 'Requester', 'Type', 'Status', 'Requested', 'Assigned', 'Update']}
          rows={(data ?? []).map((request) => [
            <div key="r"><span className="mono">{request.request_number}</span><div className="small muted">{shortId(request.id)}</div></div>,
            <span className="mono small" key="p">{shortId(request.requester_profile_id)}</span>,
            titleize(request.request_type),
            <StatusBadge key="s" value={request.status} />,
            <span className="small muted" key="d">{formatDate(request.requested_at)}</span>,
            <span className="mono small" key="a">{request.assigned_to ? shortId(request.assigned_to) : 'Unassigned'}</span>,
            <form action={updateDataRequestAction} className="form" style={{ minWidth: 190, gap: 5 }} key="u">
              <input type="hidden" name="request_id" value={request.id} />
              <select className="input" name="status" defaultValue={request.status}>
                {['received', 'identity_verifying', 'in_progress', 'completed'].map((value) => <option value={value} key={value}>{titleize(value)}</option>)}
              </select>
              <button className="btn btn-primary btn-sm" type="submit">Save</button>
            </form>,
          ])}
          empty="No data requests found."
        />
      </div>
    </>
  );
}
