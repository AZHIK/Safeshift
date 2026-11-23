import Link from 'next/link';
import { acknowledgeAlertAction, resolveIncidentAction } from '@/app/actions/admin';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

export default async function IncidentsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('incidents');
  const params = await searchParams;
  const supabase = await createClient();
  const [{ data: alerts, error: alertError }, { data: incidents, error: incidentError }] =
    await Promise.all([
      supabase
        .from('trip_alerts')
        .select(
          'id, job_id, profile_id, alert_type, status, details, acknowledged_at, resolved_at, created_at',
        )
        .order('created_at', { ascending: false })
        .limit(50),
      supabase
        .from('incidents')
        .select(
          'id, job_id, reported_by, incident_type, severity, status, description, occurred_at, resolved_at, resolution_summary',
        )
        .order('occurred_at', { ascending: false })
        .limit(50),
    ]);

  return (
    <>
      <PageHeader records={['incidents', 'alerts']}
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
            <p className="card-sub">
              Acknowledgement and resolution are recorded against the alert.
            </p>
          </div>
          <DataTable
            columns={['Alert', 'Job', 'Type', 'Status', 'Details', 'Raised']}
            rows={(alerts ?? []).map((alert) => [
              <span className="mono" key="a">
                {shortId(alert.id)}
              </span>,
              <span className="mono small" key="j">
                {shortId(alert.job_id)}
              </span>,
              titleize(alert.alert_type),
              <StatusBadge key="s" value={alert.status} />,
              <span className="small" key="d">
                {alert.details ?? '—'}
              </span>,
              <span className="small muted" key="t">
                {formatDate(alert.created_at)}
              </span>,
            ])}
            actions={(alerts ?? []).map((alert) => (
              <RecordActions
                key={alert.id}
                table="trip_alerts"
                id={alert.id}
                viewHref={alert.job_id ? `/jobs/${alert.job_id}` : undefined}
                items={[
                  ...(alert.status === 'open'
                    ? [{ kind: 'form' as const, label: 'Acknowledge', action: acknowledgeAlertAction, fields: { alert_id: alert.id, status: 'acknowledged' } }]
                    : []),
                  ...(alert.status !== 'resolved'
                    ? [{ kind: 'form' as const, label: 'Resolve', action: acknowledgeAlertAction, fields: { alert_id: alert.id, status: 'resolved' }, confirm: 'Mark this alert resolved?' }]
                    : []),
                  ...(alert.profile_id ? [{ kind: 'link' as const, label: 'Open person', href: `/users/${alert.profile_id}` }] : []),
                ]}
              />
            ))}
            empty="No SOS or trip alerts."
          />
        </div>
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Reported incidents</h2>
            <p className="card-sub">
              Accidents, theft, harassment, damage, medical, security, and other safety events.
            </p>
          </div>
          <DataTable
            columns={[
              'Incident',
              'Job',
              'Type',
              'Severity',
              'Status',
              'Description',
              'Occurred',
            ]}
            rows={(incidents ?? []).map((incident) => [
              <span className="mono" key="i">
                <Link href={'/incidents/'+incident.id}>{shortId(incident.id)}</Link>
              </span>,
              <span className="mono small" key="j">
                {shortId(incident.job_id)}
              </span>,
              titleize(incident.incident_type),
              <StatusBadge key="v" value={incident.severity} />,
              <StatusBadge key="s" value={incident.status} />,
              <span className="small" key="d" style={{ maxWidth: 280 }}>
                {incident.description}
              </span>,
              <span className="small muted" key="o">
                {formatDate(incident.occurred_at)}
              </span>,
            ])}
            actions={(incidents ?? []).map((incident) => (
              <RecordActions
                key={incident.id}
                table="incidents"
                id={incident.id}
                viewHref={`/incidents/${incident.id}`}
                items={[
                  ...(incident.job_id ? [{ kind: 'link' as const, label: 'Open job', href: `/jobs/${incident.job_id}` }] : []),
                  ...['open', 'investigating', 'resolved', 'closed']
                    .filter((status) => status !== incident.status)
                    .map((status) => ({
                      kind: 'form' as const,
                      label: `Mark ${status}`,
                      action: resolveIncidentAction,
                      fields: { incident_id: incident.id, status },
                    })),
                ]}
              />
            ))}
            empty="No reported incidents."
          />
        </div>
      </div>
    </>
  );
}
