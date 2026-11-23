import { expect, it } from 'vitest';
import { canSee } from '@/lib/areas';
it('combines grants, recognizes custom roles, and reflects revoked access', () => {
  const held = new Set(['manage_pricing', 'view_all_tickets']);
  expect(canSee(held, 'pricing', 'city_lead')).toBe(true);
  expect(canSee(held, 'support', 'city_lead')).toBe(true);
  held.delete('manage_pricing');
  expect(canSee(held, 'pricing', 'super_admin')).toBe(false);
  expect(canSee(held, 'unregistered', 'city_lead')).toBe(false);
});
it('keeps the owner fleet view available', () => {
  expect(canSee(new Set(), 'fleets', 'fleet_owner')).toBe(true);
  expect(canSee(new Set(), 'payments', 'fleet_owner')).toBe(false);
});
