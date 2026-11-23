import Link from 'next/link';

import { approveVerificationAction, rejectVerificationAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { recordHref } from '@/lib/data-records';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

export default async function VerificationsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('verifications');
  const params = await searchParams;
  const status = typeof params.status === 'string' ? params.status : 'pending';
  const supabase = await createClient();
  let query = supabase
    .from('verification_requests')
    .select(
      'id, request_type, status, priority, submitted_at, decision_notes, driver_id, vehicle_id, business_account_id, vehicles(registration_number), business_accounts(legal_name, registration_number)',
    )
    .order('submitted_at', { ascending: true })
    .limit(100);
  if (status !== 'all') query = query.eq('status', status);
  const { data, error } = await query;

  const rows = (data ?? []).map((request) => {
    const vehicle = request.vehicles as { registration_number?: string } | null;
    const business = request.business_accounts as {
      legal_name?: string;
      registration_number?: string;
    } | null;
    const subject =
      request.request_type === 'business_verification' ? (
        (business?.legal_name ?? shortId(request.business_account_id))
      ) : request.request_type === 'vehicle_verification' ? (
        (vehicle?.registration_number ?? shortId(request.vehicle_id))
      ) : request.driver_id ? (
        <Link href={`/drivers/${request.driver_id}`}>{shortId(request.driver_id)}</Link>
      ) : (
        shortId(request.driver_id)
      );
    return [
      <div key="r">
        <strong>{titleize(request.request_type)}</strong>
        <div className="small muted mono">{shortId(request.id)}</div>
      </div>,
      <div key="s">
        {subject}
        {business?.registration_number ? (
          <div className="small muted">{business.registration_number}</div>
        ) : null}
      </div>,
      <StatusBadge key="b" value={request.status} />,
      <StatusBadge key="p" value={request.priority} />,
      <span className="small muted" key="d">
        {formatDate(request.submitted_at)}
      </span>,
    ];
  });

  return (
    <>
      <PageHeader records={['verifications']}
        title="Verification queue"
        description="Review driver identity, vehicle documents, and business registrations. Decisions are audited and update the subject immediately."
        actions={
          <>
            <Link className="btn" href="/verifications?status=pending">
              Pending
            </Link>
            <Link className="btn" href="/verifications?status=in_review">
              In review
            </Link>
            <Link className="btn" href="/verifications?status=all">
              All
            </Link>
          </>
        }
      />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Request', 'Subject', 'Status', 'Priority', 'Submitted']}
          rows={rows}
          actions={(data ?? []).map((request) => (
            <RecordActions
              key={request.id}
              table="verification_requests"
              id={request.id}
              items={[
                ...(['pending', 'in_review'].includes(request.status)
                  ? [
                      {
                        kind: 'form' as const,
                        label: 'Approve',
                        action: approveVerificationAction,
                        fields: { request_id: request.id },
                        confirm: 'Approve this verification? The driver, vehicle or business becomes verified.',
                      },
                      {
                        kind: 'form' as const,
                        label: 'Reject',
                        action: rejectVerificationAction,
                        fields: { request_id: request.id },
                        reason: 'Rejection reason (shown to the applicant)',
                        danger: true,
                      },
                    ]
                  : []),
                ...(request.driver_id ? [{ kind: 'link' as const, label: 'Open driver', href: `/drivers/${request.driver_id}` }] : []),
                ...(request.vehicle_id ? [{ kind: 'link' as const, label: 'Open vehicle', href: recordHref('vehicles', request.vehicle_id) }] : []),
              ]}
            />
          ))}
          empty="No verification requests in this view."
        />
      </div>
    </>
  );
}
