import { acknowledgeAlertAction, resolveIncidentAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function IncidentsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('incidents');
  const params = await searchParams;
  const supabase = await createClient();
  const [{ data: alerts, error: alertError }, { data: incidents, error: incidentError }] = await Promise.all([
    supabase.from('trip_alerts').select('id, job_id, profile_id, alert_type, status, details, acknowledged_at, resolved_at, created_at').order('created_at', { ascending: false }).limit(50),
    supabase.from('incidents').select('id, job_id, reported_by, incident_type, severity, status, description, occurred_at, resolved_at, resolution_summary').order('occurred_at', { ascending: false }).limit(50),
  ]);

  return (
    <>
      <PageHeader
        title="Incidents & SOS"
        description="On-call safety desk for SOS alerts, emergency contacts, and formally reported incidents."
      />
      <Notice searchParams={params} />
      {alertError ? <div className="notice notice-error">{alertError.message}</div> : null}
      {incidentError ? <div className="notice notice-error">{incidentError.message}</div> : null}
      <div className="section-stack">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">SOS & trip alerts</h2>
            <p className="card-sub">Acknowledgement and resolution are recorded against the alert.</p>
          </div>
          <DataTable
            columns={['Alert', 'Job', 'Type', 'Status', 'Details', 'Raised', 'Action']}
            rows={(alerts ?? []).map((alert) => [
              <span className="mono" key="a">{shortId(alert.id)}</span>,
              <span className="mono small" key="j">{shortId(alert.job_id)}</span>,
              titleize(alert.alert_type),
              <StatusBadge key="s" value={alert.status} />,
              <span className="small" key="d">{alert.details ?? '—'}</span>,
              <span className="small muted" key="t">{formatDate(alert.created_at)}</span>,
              <div key="x" style={{ display: 'flex', gap: 6 }}>
                {alert.status === 'open' ? (
                  <form action={acknowledgeAlertAction}>
                    <input type="hidden" name="alert_id" value={alert.id} />
                    <input type="hidden" name="status" value="acknowledged" />
                    <button className="btn btn-sm" type="submit">Acknowledge</button>
                  </form>
                ) : null}
                {alert.status !== 'resolved' ? (
                  <form action={acknowledgeAlertAction}>
                    <input type="hidden" name="alert_id" value={alert.id} />
                    <input type="hidden" name="status" value="resolved" />
                    <button className="btn btn-primary btn-sm" type="submit">Resolve</button>
                  </form>
                ) : null}
              </div>,
            ])}
            empty="No SOS or trip alerts."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Reported incidents</h2>
            <p className="card-sub">Accidents, theft, harassment, damage, medical, security, and other safety events.</p>
          </div>
          <DataTable
            columns={['Incident', 'Job', 'Type', 'Severity', 'Status', 'Description', 'Occurred', 'Action']}
            rows={(incidents ?? []).map((incident) => [
              <span className="mono" key="i">{shortId(incident.id)}</span>,
              <span className="mono small" key="j">{shortId(incident.job_id)}</span>,
              titleize(incident.incident_type),
              <StatusBadge key="v" value={incident.severity} />,
              <StatusBadge key="s" value={incident.status} />,
              <span className="small" key="d" style={{ maxWidth: 280 }}>{incident.description}</span>,
              <span className="small muted" key="o">{formatDate(incident.occurred_at)}</span>,
              <form action={resolveIncidentAction} className="form" style={{ minWidth: 150, gap: 5 }} key="a">
                <input type="hidden" name="incident_id" value={incident.id} />
                <select className="input" name="status" defaultValue={incident.status}>
                  {['open', 'investigating', 'resolved', 'closed'].map((value) => <option value={value} key={value}>{titleize(value)}</option>)}
                </select>
                <button className="btn btn-primary btn-sm" type="submit">Save</button>
              </form>,
            ])}
            empty="No reported incidents."
          />
        </div>
      </div>
    </>
  );
}
