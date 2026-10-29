import { createAnonClient } from '@/lib/supabase/anon';
import { formatDate, titleize } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Snapshot = {
  job_id?: string;
  status?: string;
  pickup?: unknown;
  destination?: unknown;
  driver_first_name?: string | null;
  vehicle_type?: string | null;
  driver_lat?: number | null;
  driver_lng?: number | null;
  location_updated_at?: string | null;
  expires_at?: string | null;
  updated_at?: string | null;
};

function place(value: unknown): string {
  if (!value) return '—';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const parts = [record.line_1, record.line_2, record.city, record.region, record.country]
      .filter((part) => typeof part === 'string' && part.trim().length > 0);
    if (parts.length) return parts.join(', ');
    const label = record.label ?? record.name ?? record.address;
    if (typeof label === 'string') return label;
  }
  return 'Shared location';
}

export default async function TripSharePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const supabase = createAnonClient();
  const { data, error } = await supabase.rpc('trip_share_snapshot', { p_token: token });
  const snapshot = data as Snapshot | null;

  if (error || !snapshot) {
    return (
      <div className="trip-page">
        <div className="trip-hero">
          <h1>Trip link unavailable</h1>
          <p>This link has expired, was revoked, or does not exist. Ask the traveller for a new link.</p>
        </div>
      </div>
    );
  }

  const location = snapshot.driver_lat != null && snapshot.driver_lng != null
    ? `${Number(snapshot.driver_lat).toFixed(4)}, ${Number(snapshot.driver_lng).toFixed(4)}`
    : 'Location not shared';

  return (
    <div className="trip-page">
      <div className="trip-hero">
        <h1>SafeShift trip</h1>
        <p>Shared by the traveller. This page updates from the live trip record.</p>
        <div className="trip-grid">
          <div className="trip-cell"><span>Status</span><strong>{titleize(snapshot.status)}</strong></div>
          <div className="trip-cell"><span>Vehicle</span><strong>{snapshot.vehicle_type ?? '—'}</strong></div>
          <div className="trip-cell"><span>Driver</span><strong>{snapshot.driver_first_name ?? 'Assigned driver'}</strong></div>
          <div className="trip-cell"><span>Last update</span><strong>{formatDate(snapshot.updated_at)}</strong></div>
        </div>
      </div>
      <div className="trip-body section-stack">
        <div className="card card-pad">
          <h2 className="card-title">Route</h2>
          <p className="small muted" style={{ marginTop: 8 }}>Pickup</p>
          <p style={{ margin: '2px 0 12px' }}>{place(snapshot.pickup)}</p>
          <p className="small muted">Destination</p>
          <p style={{ margin: '2px 0 0' }}>{place(snapshot.destination)}</p>
        </div>
        <div className="card card-pad">
          <h2 className="card-title">Approximate driver position</h2>
          <p className="small muted">Coarse coordinates only. Exact live tracking is intentionally not exposed on public links.</p>
          <p className="mono" style={{ marginTop: 10 }}>{location}</p>
          <p className="small muted" style={{ marginTop: 8 }}>Updated {formatDate(snapshot.location_updated_at)}</p>
        </div>
        <div className="card card-pad">
          <h2 className="card-title">Safety</h2>
          <p className="small muted">If you believe the traveller is in immediate danger, contact local emergency services. SafeShift support can be reached from the app.</p>
          <p className="small muted" style={{ marginTop: 8 }}>Link expires {formatDate(snapshot.expires_at)}.</p>
        </div>
      </div>
    </div>
  );
}
