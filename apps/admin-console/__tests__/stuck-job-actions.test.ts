import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createMockClient, type MockClient, type MockRpcHandler } from './helpers/mock-supabase';

const JOB_ID = 'aaaaaaaa-1111-4111-8111-111111111111';

vi.mock('next/cache', () => ({ revalidatePath: vi.fn(), revalidateTag: vi.fn() }));

// redirect() throws in Next; capture the target instead.
class Redirect extends Error {
  constructor(public readonly url: string) {
    super(url);
  }
}
vi.mock('next/navigation', () => ({
  redirect: vi.fn((url: string) => {
    throw new Redirect(url);
  }),
}));

let currentClient: MockClient;
vi.mock('@/lib/supabase/server', () => ({ createClient: vi.fn(async () => currentClient) }));

async function run(action: (fd: FormData) => Promise<void>, fields: Record<string, string>) {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) fd.set(k, v);
  try {
    await action(fd);
  } catch (error) {
    if (error instanceof Redirect) return decodeURIComponent(error.url);
    throw error;
  }
  throw new Error('action did not redirect');
}

function client(rpc: MockRpcHandler) {
  currentClient = createMockClient(() => ({ data: null, error: null }), rpc);
  return currentClient;
}

describe('stuck job actions', () => {
  beforeEach(() => vi.resetModules());

  it('re-dispatches through job_request_dispatch and reports the offers', async () => {
    const c = client(() => ({ data: { count: 2, reason: null }, error: null }));
    const { redispatchJobAction } = await import('@/app/actions/jobs');
    const url = await run(redispatchJobAction, { job_id: JOB_ID });
    expect(c.rpcCalls).toEqual([{ name: 'job_request_dispatch', args: { p_job_id: JOB_ID } }]);
    expect(url).toBe('/jobs/stuck?ok=Offered to 2 drivers.');
  });

  it('explains when no driver could be offered', async () => {
    client(() => ({
      data: { count: 0, reason: 'no matching driver is free right now' },
      error: null,
    }));
    const { redispatchJobAction } = await import('@/app/actions/jobs');
    const url = await run(redispatchJobAction, { job_id: JOB_ID });
    expect(url).toContain('No driver offered: no matching driver is free right now');
  });

  it('releases the driver with the operations reason', async () => {
    const c = client(() => ({ data: { count: 1 }, error: null }));
    const { releaseDriverAction } = await import('@/app/actions/jobs');
    const url = await run(releaseDriverAction, { job_id: JOB_ID, reason: 'GPS silent' });
    expect(c.rpcCalls[0]).toEqual({
      name: 'job_driver_release',
      args: { p_job_id: JOB_ID, p_reason: 'GPS silent' },
    });
    expect(url).toContain('?ok=Driver released');
  });

  it('cancels as the signed-in operator and requires a reason', async () => {
    const c = client(() => ({ data: null, error: null }));
    const { cancelJobAsOpsAction } = await import('@/app/actions/jobs');
    expect(await run(cancelJobAsOpsAction, { job_id: JOB_ID, reason: '' })).toContain(
      'error=Give a reason',
    );
    expect(c.rpcCalls).toHaveLength(0);

    const url = await run(cancelJobAsOpsAction, { job_id: JOB_ID, reason: 'Customer unreachable' });
    expect(c.rpcCalls[0].name).toBe('job_cancel');
    expect(c.rpcCalls[0].args).toMatchObject({
      p_job_id: JOB_ID,
      p_reason: 'Customer unreachable',
    });
    expect(typeof c.rpcCalls[0].args.p_cancelled_by).toBe('string');
    expect(url).toBe('/jobs/stuck?ok=Job cancelled.');
  });

  it('surfaces server errors and rejects malformed ids', async () => {
    client(() => ({
      data: null,
      error: { message: 'this job can no longer be released; contact support' },
    }));
    const { releaseDriverAction } = await import('@/app/actions/jobs');
    expect(await run(releaseDriverAction, { job_id: JOB_ID })).toContain(
      'error=this job can no longer be released',
    );
    expect(await run(releaseDriverAction, { job_id: 'nope' })).toContain(
      'error=Missing or invalid job id',
    );
  });
});
