'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';

const STUCK_PATH = '/jobs/stuck';

function back(kind: 'ok' | 'error', message: string): never {
  redirect(`${STUCK_PATH}?${kind}=${encodeURIComponent(message)}`);
}

function jobIdFrom(formData: FormData): string {
  const jobId = String(formData.get('job_id') ?? '').trim();
  if (!/^[0-9a-f-]{36}$/i.test(jobId)) back('error', 'Missing or invalid job id.');
  return jobId;
}

/** Runs the next dispatch round now (radius and attempt cap stay server-side). */
export async function redispatchJobAction(formData: FormData) {
  const jobId = jobIdFrom(formData);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('job_request_dispatch', { p_job_id: jobId });
  if (error) back('error', error.message);
  revalidatePath(STUCK_PATH);
  const count = Number((data as { count?: number } | null)?.count ?? 0);
  const reason = (data as { reason?: string | null } | null)?.reason;
  back(
    'ok',
    count > 0
      ? `Offered to ${count} driver${count === 1 ? '' : 's'}.`
      : `No driver offered: ${reason ?? 'no match yet'}.`,
  );
}

/** Takes the job off its driver and re-dispatches it to someone else. */
export async function releaseDriverAction(formData: FormData) {
  const jobId = jobIdFrom(formData);
  const reason = String(formData.get('reason') ?? '').trim() || 'Released by operations';
  const supabase = await createClient();
  const { error } = await supabase.rpc('job_driver_release', {
    p_job_id: jobId,
    p_reason: reason,
  });
  if (error) back('error', error.message);
  revalidatePath(STUCK_PATH);
  back('ok', 'Driver released. The move is searching for a new driver.');
}

/** Cancels as operations. job_cancel charges no fee for an admin cancellation. */
export async function cancelJobAsOpsAction(formData: FormData) {
  const jobId = jobIdFrom(formData);
  const reason = String(formData.get('reason') ?? '').trim();
  if (reason.length < 3) back('error', 'Give a reason for cancelling.');
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) back('error', 'Your session has expired.');
  const { error } = await supabase.rpc('job_cancel', {
    p_job_id: jobId,
    p_cancelled_by: auth.user.id,
    p_reason: reason,
  });
  if (error) back('error', error.message);
  revalidatePath(STUCK_PATH);
  revalidatePath('/jobs');
  back('ok', 'Job cancelled.');
}
