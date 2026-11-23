'use client';
export default function ConsoleError({ reset }: { reset: () => void }) {
  return (
    <section className="card card-pad" role="alert">
      <h1>This page could not load</h1>
      <p>Try the request again. If it keeps failing, return to the dashboard.</p>
      <button className="btn" onClick={reset}>
        Try again
      </button>
    </section>
  );
}
