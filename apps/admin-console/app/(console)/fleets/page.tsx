import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function FleetsPage() {
  const session = await requireArea('fleets');
  const supabase = await createClient();
  let fleetQuery = supabase
    .from('fleets')
    .select('id, name, trading_name, registration_number, contact_email, contact_phone, owner_profile_id, is_active, verified_at, commission_rate_override, created_at')
    .order('created_at', { ascending: false })
    .limit(100);
  if (session.role === 'fleet_owner') {
    fleetQuery = fleetQuery.eq('owner_profile_id', session.userId);
  }
  const { data: fleets, error } = await fleetQuery;
  const fleetIds = (fleets ?? []).map((fleet) => fleet.id);

  const [{ data: vehicles }, { data: members }, { data: billing }] = fleetIds.length
    ? await Promise.all([
        supabase
          .from('fleet_vehicles')
          .select('fleet_id, is_active, vehicles(registration_number, verification_status, capacity_kg, vehicle_types(name))')
          .in('fleet_id', fleetIds),
        supabase
          .from('fleet_members')
          .select('fleet_id, driver_id, role, is_active')
          .in('fleet_id', fleetIds),
        supabase
          .from('fleet_billing_events')
          .select('fleet_id, job_id, fleet_commission_amount, currency_code, accrued_at')
          .in('fleet_id', fleetIds)
          .order('created_at', { ascending: false })
          .limit(100),
      ])
    : [{ data: [] }, { data: [] }, { data: [] }];
  const memberProfiles = await loadProfileSummaries(supabase, (members ?? []).map((member) => member.driver_id));

  const vehiclesByFleet = new Map<string, typeof vehicles>();
  for (const vehicle of vehicles ?? []) {
    const list = vehiclesByFleet.get(vehicle.fleet_id) ?? [];
    list.push(vehicle);
    vehiclesByFleet.set(vehicle.fleet_id, list);
  }
  const membersByFleet = new Map<string, typeof members>();
  for (const member of members ?? []) {
    const list = membersByFleet.get(member.fleet_id) ?? [];
    list.push(member);
    membersByFleet.set(member.fleet_id, list);
  }
  const billingByFleet = new Map<string, typeof billing>();
  for (const event of billing ?? []) {
    const list = billingByFleet.get(event.fleet_id) ?? [];
    list.push(event);
    billingByFleet.set(event.fleet_id, list);
  }

  return (
    <>
      <PageHeader
        title={session.role === 'fleet_owner' ? 'My fleet' : 'Fleets'}
        description="Fleet owners manage their own vehicles and drivers. Operations staff can see all fleets, verification state, and billing events."
      />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      {(fleets ?? []).length === 0 ? <div className="card table-empty">No fleets found.</div> : null}
      <div className="section-stack">
        {(fleets ?? []).map((fleet) => {
          const fleetVehicles = vehiclesByFleet.get(fleet.id) ?? [];
          const fleetMembers = membersByFleet.get(fleet.id) ?? [];
          const events = billingByFleet.get(fleet.id) ?? [];
          return (
            <div className="card" key={fleet.id}>
              <div className="card-pad">
                <div className="inline" style={{ justifyContent: 'space-between', width: '100%', flexWrap: 'wrap' }}>
                  <div>
                    <h2 className="card-title" style={{ fontSize: 18 }}>{fleet.name}</h2>
                    <p className="card-sub">{fleet.trading_name ?? 'Fleet account'} · {fleet.registration_number ?? 'No registration number'}</p>
                  </div>
                  <div className="inline">
                    <StatusBadge value={fleet.verified_at ? 'verified' : 'pending'} />
                    <StatusBadge value={fleet.is_active ? 'active' : 'disabled'} />
                  </div>
                </div>
                <div className="grid grid-3" style={{ marginTop: 12 }}>
                  <div className="trip-cell" style={{ background: 'var(--surface-2)', borderColor: 'var(--line)', color: 'var(--ink)' }}><span style={{ color: 'var(--muted)' }}>Contact</span><strong className="small">{fleet.contact_phone ?? fleet.contact_email ?? '—'}</strong></div>
                  <div className="trip-cell" style={{ background: 'var(--surface-2)', borderColor: 'var(--line)', color: 'var(--ink)' }}><span style={{ color: 'var(--muted)' }}>Commission override</span><strong className="small">{fleet.commission_rate_override == null ? 'Default' : `${fleet.commission_rate_override}%`}</strong></div>
                  <div className="trip-cell" style={{ background: 'var(--surface-2)', borderColor: 'var(--line)', color: 'var(--ink)' }}><span style={{ color: 'var(--muted)' }}>Created</span><strong className="small">{formatDate(fleet.created_at)}</strong></div>
                </div>
              </div>
              <div className="grid grid-2">
                <div>
                  <div className="card-pad" style={{ paddingBottom: 0 }}><h3 className="card-title">Vehicles</h3><p className="card-sub">Active fleet vehicles and verification.</p></div>
                  <DataTable
                    columns={['Registration', 'Type', 'Capacity', 'Verification', 'Fleet status']}
                    rows={fleetVehicles.map((entry) => {
                      const vehicle = entry.vehicles as { registration_number?: string; verification_status?: string; capacity_kg?: number; vehicle_types?: { name?: string } | null } | null;
                      return [vehicle?.registration_number ?? '—', vehicle?.vehicle_types?.name ?? '—', `${vehicle?.capacity_kg ?? 0} kg`, <StatusBadge key="v" value={vehicle?.verification_status} />, <StatusBadge key="s" value={entry.is_active ? 'active' : 'paused'} />];
                    })}
                    empty="No vehicles assigned."
                  />
                </div>
                <div>
                  <div className="card-pad" style={{ paddingBottom: 0 }}><h3 className="card-title">Drivers</h3><p className="card-sub">Fleet members and their role.</p></div>
                  <DataTable
                    columns={['Driver', 'Phone', 'Role', 'Status']}
                    rows={fleetMembers.map((entry) => {
                      const driver = memberProfiles.get(entry.driver_id);
                      return [driver?.full_name ?? shortId(entry.driver_id), driver?.phone ?? '—', entry.role, <StatusBadge key="s" value={entry.is_active ? 'active' : 'paused'} />];
                    })}
                    empty="No drivers assigned."
                  />
                </div>
              </div>
              <div className="card-pad">
                <h3 className="card-title">Recent billing events</h3>
                <DataTable
                  columns={['Job', 'Commission', 'When']}
                  rows={events.slice(0, 5).map((event) => [<span className="mono small" key="j">{shortId(event.job_id)}</span>, `${Number(event.fleet_commission_amount ?? 0).toLocaleString()} ${event.currency_code ?? 'TZS'}`, <span className="small muted" key="d">{formatDate(event.accrued_at)}</span>])}
                  empty="No billing events recorded."
                />
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
