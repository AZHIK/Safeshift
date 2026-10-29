export function Notice({ searchParams }: { searchParams?: Record<string, string | string[] | undefined> }) {
  const ok = typeof searchParams?.ok === 'string' ? searchParams.ok : null;
  const error = typeof searchParams?.error === 'string' ? searchParams.error : null;
  if (!ok && !error) return null;
  return <div className={`notice ${error ? 'notice-error' : 'notice-ok'}`}>{error ?? ok}</div>;
}
