const areaPermissions: Record<string, readonly string[]> = {
  governance: ['export_regulator_reports','review_government_requests','manage_data_requests'],
  announcements: ['send_notification'],
  analytics: ['view_analytics'], audit: ['view_audit'],
  jobs: ['view_all_jobs', 'assign_drivers'],
  users: ['view_all_users', 'manage_customers', 'suspend_user'],
  drivers: ['view_all_drivers', 'suspend_driver', 'verify_driver'],
  fleets: ['view_all_fleets', 'manage_fleets', 'view_fleet'],
  catalog: ['manage_vehicle_catalog', 'manage_cargo_catalog'],
  verifications: ['view_verifications', 'verify_driver', 'verify_vehicle'],
  incidents: ['view_incidents', 'manage_incidents'],
  disputes: ['view_all_disputes', 'resolve_disputes', 'manage_disputes'],
  support: ['view_all_tickets', 'manage_tickets'],
  payments: ['view_all_payments', 'manage_payments', 'process_refunds'],
  payouts: ['view_payouts', 'process_payouts', 'manage_payouts'],
  pricing: ['manage_pricing', 'manage_regulated_tariffs'],
  promos: ['view_promotions', 'manage_promotions'],
  'data-requests': ['manage_data_requests'],
};

export function canSee(permissions: ReadonlySet<string>, area: string, role: string) {
  if (area === 'dashboard' || area === 'settings') return true;
  if (area === 'fleets' && role === 'fleet_owner') return true;
  return areaPermissions[area]?.some(permission => permissions.has(permission)) ?? false;
}
