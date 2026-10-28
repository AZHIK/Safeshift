import { JOB_STATUSES, type JobStatus } from '@safeshift/shared-types';

const currentStatus: JobStatus = 'in_transit';

export default function HomePage() {
  return (
    <main className="page">
      <section className="hero">
        <p className="eyebrow">SafeShift web workspace</p>
        <h1>One monorepo. One data contract.</h1>
        <p className="lede">
          This Next.js app, the Flutter apps, Supabase migrations, Edge Functions, and shared
          packages now build from the same repository.
        </p>
        <div className="status">
          <span>Example job status</span>
          <strong>{currentStatus}</strong>
        </div>
      </section>

      <section className="card">
        <h2>Shared job lifecycle</h2>
        <p>
          These values come from <code>@safeshift/shared-types</code>, generated from the local
          Postgres schema.
        </p>
        <ul className="statuses">
          {JOB_STATUSES.map((status) => (
            <li key={status} className={status === currentStatus ? 'active' : undefined}>
              {status}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
