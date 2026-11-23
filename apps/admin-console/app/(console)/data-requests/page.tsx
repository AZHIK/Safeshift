import { updateDataRequestAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { loadEntityNames } from '@/lib/record-labels';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

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
    .select(
      'id, request_number, requester_profile_id, request_type, status, reason, requested_at, verified_at, completed_at, assigned_to, notes',
    )
    .order('requested_at', { ascending: false })
    .limit(100);
  const names = await loadEntityNames({
    profiles: (data ?? []).flatMap((r) => [r.requester_profile_id, r.assigned_to]),
  });

  return (
    <>
      <PageHeader records={['data-requests']}
        title="Data requests"
        description="Privacy export, deletion, rectification, and processing-restriction requests. Identity verification is required before delivery."
      />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Request', 'Requester', 'Type', 'Status', 'Requested', 'Assigned']}
          rows={(data ?? []).map((request) => [
            <div key="r">
              <span className="mono">{request.request_number}</span>
            </div>,
            <span className="small" key="p">
              {names.profiles[request.requester_profile_id] ?? shortId(request.requester_profile_id)}
            </span>,
            titleize(request.request_type),
            <StatusBadge key="s" value={request.status} />,
            <span className="small muted" key="d">
              {formatDate(request.requested_at)}
            </span>,
            <span className="small" key="a">
              {request.assigned_to ? (names.profiles[request.assigned_to] ?? shortId(request.assigned_to)) : 'Unassigned'}
            </span>,
          ])}
          actions={(data ?? []).map((request) => (
            <RecordActions
              key={request.id}
              table="data_subject_requests"
              id={request.id}
              items={[
                ...(request.requester_profile_id
                  ? [{ kind: 'link' as const, label: 'Open requester', href: `/users/${request.requester_profile_id}` }]
                  : []),
                ...['received', 'identity_verifying', 'in_progress', 'completed']
                  .filter((status) => status !== request.status)
                  .map((status) => ({
                    kind: 'form' as const,
                    label: `Mark ${titleize(status).toLowerCase()}`,
                    action: updateDataRequestAction,
                    fields: { request_id: request.id, status },
                    ...(status === 'completed' ? { confirm: 'Mark this request completed? The requester is told it is done.' } : {}),
                  })),
              ]}
            />
          ))}
          empty="No data requests found."
        />
      </div>
    </>
  );
}
