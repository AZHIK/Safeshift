export default function ConsoleLoading() {
  return (
    <div role="status" aria-label="Loading page" aria-live="polite">
      <div className="page-head">
        <div style={{ width: 'min(360px, 100%)' }}>
          <span className="skeleton" style={{ height: 28, width: '70%' }} />
          <span className="skeleton" style={{ marginTop: 10, width: '100%' }} />
        </div>
      </div>
      <div className="card card-pad">
        <span className="skeleton" style={{ width: '35%', marginBottom: 24 }} />
        <span className="skeleton" style={{ width: '100%', marginBottom: 18 }} />
        <span className="skeleton" style={{ width: '92%', marginBottom: 18 }} />
        <span className="skeleton" style={{ width: '96%' }} />
      </div>
    </div>
  );
}
