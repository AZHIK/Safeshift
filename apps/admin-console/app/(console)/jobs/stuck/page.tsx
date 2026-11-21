import Link from 'next/link';

import { cancelJobAsOpsAction, redispatchJobAction, releaseDriverAction } from '@/app/actions/jobs';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { shortId } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

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
          columns={['Job', 'Issue', 'Status', 'For', 'Customer', 'Driver', 'Action']}
          rows={rows.map((job) => [
            <span className="mono" key="j">
              {shortId(job.job_id)}
            </span>,
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
            <div key="a" style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {job.suggested_action === 'redispatch' ? (
                <form action={redispatchJobAction}>
                  <input type="hidden" name="job_id" value={job.job_id} />
                  <button className="btn btn-primary btn-sm" type="submit">
                    Search again
                  </button>
                </form>
              ) : null}
              {job.suggested_action === 'release' ? (
                <form action={releaseDriverAction}>
                  <input type="hidden" name="job_id" value={job.job_id} />
                  <input
                    type="hidden"
                    name="reason"
                    value={`Released by operations: ${job.issue}`}
                  />
                  <button className="btn btn-primary btn-sm" type="submit">
                    Reassign driver
                  </button>
                </form>
              ) : null}
              <form action={cancelJobAsOpsAction} style={{ display: 'flex', gap: 4 }}>
                <input type="hidden" name="job_id" value={job.job_id} />
                <input
                  className="input input-sm"
                  name="reason"
                  placeholder="Reason to cancel"
                  aria-label="Reason to cancel"
                  required
                  minLength={3}
                />
                <button className="btn btn-sm" type="submit">
                  Cancel
                </button>
              </form>
            </div>,
          ])}
          empty="Nothing is stuck right now."
        />
      </div>
    </>
  );
}
