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
