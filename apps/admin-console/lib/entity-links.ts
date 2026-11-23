import { encodeKey } from './data-records';

/** Console screens for the entity types the audit log records. */
const SCREENS: Record<string, string> = {
  profile: '/users/', profiles: '/users/', user: '/users/',
  driver: '/drivers/', drivers: '/drivers/',
  job: '/jobs/', jobs: '/jobs/',
  payment: '/payments/', payments: '/payments/',
  incident: '/incidents/', incidents: '/incidents/',
  invoice: '/invoices/', invoices: '/invoices/',
  promo_code: '/promos/', promo_codes: '/promos/',
  pricing_plan: '/pricing/', pricing_plans: '/pricing/',
  payout_batch: '/payouts/', payout_batches: '/payouts/',
};

const TABLE_RE = /^[a-z_][a-z0-9_]*$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Where to open an audited entity, or null when it has no page. */
export function entityHref(type: unknown, id: unknown): string | null {
  const t = String(type ?? '').toLowerCase();
  const i = String(id ?? '');
  if (!t || !UUID_RE.test(i)) return null;
  if (SCREENS[t]) return SCREENS[t] + i;
  return TABLE_RE.test(t) ? `/data/${t}/${encodeKey({ id: i })}` : null;
}

const ENTITY_TABLE: Record<string, string> = {
  profile: 'profiles', user: 'profiles', driver: 'drivers', job: 'jobs', payment: 'payments',
  incident: 'incidents', invoice: 'invoices', promo_code: 'promo_codes', pricing_plan: 'pricing_plans',
  payout_batch: 'payout_batches', payout: 'payouts', vehicle: 'vehicles', fleet: 'fleets',
  dispute: 'disputes', support_ticket: 'support_tickets', business_account: 'business_accounts',
};

/** The table an audited entity type lives in, or null. */
export function entityTable(type: unknown): string | null {
  const t = String(type ?? '').toLowerCase();
  if (ENTITY_TABLE[t]) return ENTITY_TABLE[t];
  return TABLE_RE.test(t) ? t : null;
}
