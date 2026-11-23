import { describe, expect, it, vi } from 'vitest';

import {
  CONFIGURATION_GROUPS,
  CONFIGURATION_PERMISSIONS,
  CONFIGURATION_RESOURCES,
  CONFIGURATION_SLUG_BY_TABLE,
  CONFIGURATION_UMBRELLA_PERMISSIONS,
} from '@/lib/configuration/resources';

vi.mock('@/lib/configuration/guard', () => ({
  getCallerPermissions: vi.fn(async () => ({
    permissions: new Set<string>(),
    roles: [],
    isSuperAdmin: false,
  })),
  hasPermission: vi.fn(async () => false),
  canManageConfiguration: vi.fn(async () => false),
  requireConfigurationPermission: vi.fn(async () => ({
    session: { userId: 'admin-1', email: null, name: 'Admin', role: 'analyst' },
    caller: { permissions: new Set<string>(), roles: [], isSuperAdmin: false },
  })),
}));

/** The permission each configuration page is expected to require. */
const EXPECTED: Record<string, string> = {
  'tax-rates':'manage_taxes', 'commission-rules':'manage_commission', surge:'manage_surge', 'zone-overrides':'adjust_pricing', retention:'manage_retention',
  'saved-replies':'manage_support',
  countries: 'manage_countries',
  'country-configurations': 'manage_countries',
  regions: 'manage_geography',
  cities: 'manage_geography',
  'service-zones': 'manage_geography',
  neighborhoods: 'manage_geography',
  addresses: 'manage_geography',
  'vehicle-types': 'manage_vehicle_catalog',
  'vehicle-makes': 'manage_vehicle_catalog',
  'vehicle-models': 'manage_vehicle_catalog',
  'vehicle-equipment': 'manage_vehicle_catalog',
  'cargo-categories': 'manage_cargo_catalog',
  'cargo-types': 'manage_cargo_catalog',
  'cargo-restrictions': 'manage_cargo_catalog',
  'cargo-packaging': 'manage_cargo_catalog',
  'document-types': 'manage_document_types',
  'verification-checklists': 'manage_document_types',
  'prohibited-items': 'manage_prohibited_items',
  'support-categories': 'manage_support',
  'notification-templates': 'manage_notifications',
  'localization-strings': 'manage_localization',
  'feature-flags': 'manage_features',
  'cancellation-policies': 'manage_cancellation_policies',
  'dispatch-rules': 'manage_dispatch',
  'rating-categories': 'manage_ratings',
  'admin-roles': 'manage_admins',
  'permissions-catalog': 'manage_admins',
};

describe('configuration permissions', () => {
  it('registers every declared configuration resource', () => {
    expect(Object.keys(CONFIGURATION_RESOURCES).sort()).toEqual(Object.keys(EXPECTED).sort());
  });

  it('requires the right permission on every page', () => {
    for (const [slug, permission] of Object.entries(EXPECTED)) {
      const resource = CONFIGURATION_RESOURCES[slug];
      expect(resource, `missing resource for ${slug}`).toBeDefined();
      expect(resource.permission, `${slug} requires the wrong permission`).toBe(permission);
    }
  });

  it('maps every table onto a page slug', () => {
    for (const resource of Object.values(CONFIGURATION_RESOURCES)) {
      expect(CONFIGURATION_SLUG_BY_TABLE[resource.table], resource.table).toBeDefined();
    }
  });

  it('lists every permission a configuration page needs', () => {
    const needed = new Set(Object.values(EXPECTED));
    for (const permission of needed) {
      expect(CONFIGURATION_PERMISSIONS).toContain(permission);
    }
  });

  it('never lets the umbrella grant the administration pages', () => {
    // 'manage_configuration' expands to every configuration permission. If it
    // also covered 'manage_admins', an operations administrator who held the
    // umbrella could mint new admin roles and escalate.
    expect(CONFIGURATION_UMBRELLA_PERMISSIONS).not.toContain('manage_admins');
    expect(CONFIGURATION_PERMISSIONS).toContain('manage_admins');

    const adminPages = Object.entries(CONFIGURATION_RESOURCES).filter(
      ([, resource]) => resource.permission === 'manage_admins',
    );
    expect(adminPages.map(([slug]) => slug)).toEqual(['admin-roles', 'permissions-catalog']);
  });

  it('keeps the administration pages out of the umbrella family', () => {
    const umbrellaFamily = [
      'manage_vehicle_catalog',
      'manage_cargo_catalog',
      'manage_document_types',
      'manage_support',
      'manage_prohibited_items',
      'manage_notifications',
      'manage_localization',
      'manage_features',
      'manage_cancellation_policies',
      'manage_dispatch',
      'manage_ratings',
      'manage_countries',
      'manage_geography',
    ];

    for (const permission of umbrellaFamily) {
      expect(CONFIGURATION_UMBRELLA_PERMISSIONS).toContain(permission);
    }
    expect(CONFIGURATION_PERMISSIONS).toContain('manage_configuration');
  });

  it('shows only the pages an administrator may open', () => {
    const operationsAdmin = [
      'manage_vehicle_catalog',
      'manage_cargo_catalog',
      'manage_document_types',
      'manage_dispatch',
      'manage_cancellation_policies',
      'manage_countries',
      'manage_geography',
    ];

    const visible = CONFIGURATION_GROUPS.flatMap((group) =>
      group.items.flatMap((item) => {
        if (!operationsAdmin.includes(item.permission)) return [];
        if (!item.children) return [item.slug];
        return item.children
          .filter((child) => operationsAdmin.includes(child.permission))
          .map((child) => child.slug);
      }),
    );

    expect(visible).toContain('countries');
    expect(visible).toContain('vehicle-types');
    expect(visible).toContain('cargo-types');
    expect(visible).toContain('document-types');
    expect(visible).toContain('dispatch-rules');
    expect(visible).toContain('cancellation-policies');

    // Not part of the operations remit.
    expect(visible).not.toContain('notification-templates');
    expect(visible).not.toContain('admin-roles');
    expect(visible).not.toContain('permissions-catalog');
  });

  it('shows the support agent only the support categories', () => {
    const supportAgent = ['manage_support'];
    const visible = CONFIGURATION_GROUPS.flatMap((group) =>
      group.items.filter((item) => supportAgent.includes(item.permission)).map((item) => item.slug),
    );

    expect(visible).toEqual(['saved-replies','support-categories']);
  });

  it('shows an analyst nothing at all', () => {
    const analyst: string[] = [];
    const visible = CONFIGURATION_GROUPS.flatMap((group) =>
      group.items.filter((item) => analyst.includes(item.permission)).map((item) => item.slug),
    );

    expect(visible).toEqual([]);
  });

  it('gives the super admin every configuration page', () => {
    const superAdmin: string[] = [...CONFIGURATION_PERMISSIONS];
    const visible = CONFIGURATION_GROUPS.flatMap((group) =>
      group.items.flatMap((item) => {
        if (!superAdmin.includes(item.permission)) return [];
        if (!item.children) return [item.slug];
        return item.children.map((child) => child.slug);
      }),
    );

    const offline = ['feature-flags', 'country-configurations', 'localization-strings'];
    expect(visible.sort()).toEqual(Object.keys(EXPECTED).filter((slug) => !offline.includes(slug)).sort());
  });

  it('uses the permission check before every write', async () => {
    const guard = await import('@/lib/configuration/guard');
    const mocked = vi.mocked(guard.hasPermission);

    mocked.mockResolvedValueOnce(false);
    const denied = await guard.hasPermission('manage_vehicle_catalog');
    expect(denied).toBe(false);

    mocked.mockResolvedValueOnce(true);
    const allowed = await guard.hasPermission('manage_vehicle_catalog');
    expect(allowed).toBe(true);
  });
});
