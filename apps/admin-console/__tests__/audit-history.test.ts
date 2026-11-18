import { beforeEach, describe, expect, it, vi } from 'vitest';

import { formatAuditValue, toCsv } from '@/components/configuration/audit-history-button';

import { createMockClient, type MockClient } from './helpers/mock-supabase';

const RECORD_ID = 'eeeeeeee-5555-4555-8555-555555555555';

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));

vi.mock('@/lib/configuration/guard', () => ({
  getCallerPermissions: vi.fn(async () => ({
    permissions: new Set(['manage_vehicle_catalog']),
    roles: ['super_admin'],
    isSuperAdmin: true,
  })),
  hasPermission: vi.fn(async () => true),
  canManageConfiguration: vi.fn(async () => true),
  requireConfigurationPermission: vi.fn(async () => ({
    session: { userId: 'admin-1', email: null, name: 'Admin', role: 'super_admin' },
    caller: {
      permissions: new Set(['manage_vehicle_catalog']),
      roles: ['super_admin'],
      isSuperAdmin: true,
    },
  })),
}));

let currentClient: MockClient;

vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(async () => currentClient),
}));

// The database returns the newest entry first.
const entries = [
  {
    entry_id: 'action:9',
    created_at: '2026-11-02T11:30:00.000Z',
    actor_id: '22222222-2222-4222-8222-222222222222',
    actor_name: 'Amina Said',
    action: 'vehicle_types.updated',
    old_value: { name: 'Pickup van' },
    new_value: { name: 'Pickup van XL' },
    source: 'admin_actions_log',
  },
  {
    entry_id: 'trigger:1',
    created_at: '2026-11-01T09:00:00.000Z',
    actor_id: '11111111-1111-4111-8111-111111111111',
    actor_name: 'Joseph Mwakalinga',
    action: 'update',
    old_value: { name: 'Pickup van', capacity_kg_max: 1200 },
    new_value: { name: 'Pickup van', capacity_kg_max: 1500 },
    source: 'audit_log',
  },
];

describe('audit history', () => {
  beforeEach(() => {
    currentClient = createMockClient(
      () => ({ data: [], error: null, count: 0 }),
      (name) => {
        if (name === 'admin_audit_history') return { data: entries, error: null };
        return { data: null, error: null };
      },
    );
  });

  it('reads the trail of one record', async () => {
    const actions = await import('@/app/(console)/settings/configuration/vehicle-types/actions');
    const result = await actions.getVehicleTypeAuditHistory(RECORD_ID);

    expect(result).toHaveLength(2);
    expect(result[0].action).toBe('vehicle_types.updated');
    expect(result[0].actor_name).toBe('Amina Said');

    const call = currentClient.rpcCalls.find((entry) => entry.name === 'admin_audit_history');
    expect(call?.args).toMatchObject({
      p_entity_type: 'vehicle_types',
      p_entity_id: RECORD_ID,
      p_permission: 'manage_vehicle_catalog',
      p_limit: 50,
    });
  });

  it('passes the date range and the actor filter through', async () => {
    const actions = await import('@/app/(console)/settings/configuration/vehicle-types/actions');
    await actions.getVehicleTypeAuditHistory(RECORD_ID, {
      limit: 10,
      from: '2026-11-01T00:00:00.000Z',
      to: '2026-11-30T00:00:00.000Z',
      actor: 'Joseph Mwakalinga',
    });

    const call = currentClient.rpcCalls.find((entry) => entry.name === 'admin_audit_history');
    expect(call?.args).toMatchObject({
      p_limit: 10,
      p_from: '2026-11-01T00:00:00.000Z',
      p_to: '2026-11-30T00:00:00.000Z',
      p_actor: 'Joseph Mwakalinga',
    });
  });

  it('returns nothing when the caller has no permission', async () => {
    const guard = await import('@/lib/configuration/guard');
    const mocked = vi.mocked(guard.getCallerPermissions);
    mocked.mockResolvedValueOnce({
      permissions: new Set<string>(),
      roles: [],
      isSuperAdmin: false,
    });

    const actions = await import('@/app/(console)/settings/configuration/vehicle-types/actions');
    const result = await actions.getVehicleTypeAuditHistory(RECORD_ID);

    expect(result).toEqual([]);
    expect(
      currentClient.rpcCalls.find((entry) => entry.name === 'admin_audit_history'),
    ).toBeUndefined();
  });

  it('formats a value for the audit table', () => {
    expect(formatAuditValue(null)).toBe('—');
    expect(formatAuditValue('plain')).toBe('plain');
    expect(formatAuditValue({ name: 'Pickup van' })).toContain('"name": "Pickup van"');
  });

  it('exports the visible entries as CSV', () => {
    const csv = toCsv(entries as never);
    const lines = csv.split('\n');

    expect(lines[0]).toBe('"Timestamp","Actor","Action","Source","Old value","New value"');
    expect(lines).toHaveLength(3);
    expect(lines[1]).toContain('"Amina Said"');
    expect(lines[1]).toContain('"admin_actions_log"');
    expect(lines[2]).toContain('"Joseph Mwakalinga"');
    expect(lines[2]).toContain('"audit_log"');
  });
});
