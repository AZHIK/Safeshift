import Link from 'next/link';

import { cancelJobAsOpsAction, redispatchJobAction, releaseDriverAction } from '@/app/actions/jobs';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { shortId } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

type StuckJob = {
  job_id: string;
  status: string;
  issue: string;
  minutes_in_status: number;
  customer_name: string | null;
  customer_id: string;
  driver_name: string | null;
  driver_id: string | null;
  driver_gps_minutes: number | null;
  dispatch_attempts: number;
  suggested_action: 'redispatch' | 'release' | 'contact';
};

function duration(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest ? `${hours} h ${rest} min` : `${hours} h`;
}

export default async function StuckJobsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('jobs');
  const params = await searchParams;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_stuck_jobs', { p_limit: 200 });
  const rows = (data ?? []) as StuckJob[];

  return (
    <>
      <PageHeader
        title="Stuck jobs"
        description="Live moves over the time limit for their stage, or with a driver whose GPS has gone quiet. Oldest first."
        actions={
          <Link className="btn" href="/jobs">
            All jobs
          </Link>
        }
      />
      <Notice searchParams={params} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Job', 'Issue', 'Status', 'For', 'Customer', 'Driver']}
          rows={rows.map((job) => [
            <Link className="mono" key="j" href={`/jobs/${job.job_id}`}>
              {shortId(job.job_id)}
            </Link>,
            <span key="i">{job.issue}</span>,
            <StatusBadge key="s" value={job.status} />,
            <span className="small" key="f">
              {duration(job.minutes_in_status)}
              {job.driver_id === null && job.dispatch_attempts > 0
                ? ` · ${job.dispatch_attempts} rounds`
                : ''}
            </span>,
            <span className="small" key="c">
              {job.customer_name ?? shortId(job.customer_id)}
            </span>,
            <span className="small" key="d">
              {job.driver_id ? (job.driver_name ?? shortId(job.driver_id)) : '—'}
              {job.driver_gps_minutes !== null && job.driver_gps_minutes >= 5 ? (
                <span className="muted"> · GPS {duration(job.driver_gps_minutes)} ago</span>
              ) : null}
            </span>,
          ])}
          actions={rows.map((job) => (
            <RecordActions
              key={job.job_id}
              table="jobs"
              id={job.job_id}
              viewHref={`/jobs/${job.job_id}`}
              items={[
                ...(job.suggested_action === 'redispatch'
                  ? [{ kind: 'form' as const, label: 'Search again', action: redispatchJobAction, fields: { job_id: job.job_id } }]
                  : []),
                ...(job.suggested_action === 'release'
                  ? [{
                      kind: 'form' as const,
                      label: 'Reassign driver',
                      action: releaseDriverAction,
                      fields: { job_id: job.job_id, reason: `Released by operations: ${job.issue}` },
                      confirm: 'The driver is released and the job goes back to dispatch.',
                    }]
                  : []),
                {
                  kind: 'form',
                  label: 'Cancel job',
                  action: cancelJobAsOpsAction,
                  fields: { job_id: job.job_id },
                  reason: 'Reason to cancel',
                  confirm: 'The customer and driver are told the job was cancelled by operations.',
                  danger: true,
                },
              ]}
            />
          ))}
          empty="Nothing is stuck right now."
        />
      </div>
    </>
  );
}
