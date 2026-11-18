import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  createMockClient,
  requestFor,
  requestsFor,
  type MockClient,
  type MockHandler,
  type MockRpcHandler,
} from './helpers/mock-supabase';

const VEHICLE_TYPE_ID = 'aaaaaaaa-1111-4111-8111-111111111111';

type PermissionSet = {
  permissions: string[];
  roles?: string[];
  isSuperAdmin?: boolean;
};

const permissionState: PermissionSet = { permissions: [] };

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));

vi.mock('@/lib/configuration/guard', () => ({
  getCallerPermissions: vi.fn(async () => ({
    permissions: new Set(permissionState.permissions),
    roles: permissionState.roles ?? [],
    isSuperAdmin: permissionState.isSuperAdmin ?? false,
  })),
  hasPermission: vi.fn(async (permission: string) =>
    permissionState.permissions.includes(permission),
  ),
  canManageConfiguration: vi.fn(async () => permissionState.permissions.length > 0),
  requireConfigurationPermission: vi.fn(async () => ({
    session: { userId: 'admin-1', email: null, name: 'Admin', role: 'super_admin' },
    caller: {
      permissions: new Set(permissionState.permissions),
      roles: permissionState.roles ?? [],
      isSuperAdmin: permissionState.isSuperAdmin ?? false,
    },
  })),
}));

let currentClient: MockClient;

vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(async () => currentClient),
}));

/** Imports the vehicle type actions with the mocks in place. */
async function loadActions() {
  return import('@/app/(console)/settings/configuration/vehicle-types/actions');
}

const vehicleTypeRow = {
  id: VEHICLE_TYPE_ID,
  country_id: null,
  code: 'pickup_van',
  name: 'Pickup van',
  description: null,
  icon_url: null,
  capacity_kg_min: 500,
  capacity_kg_max: 1500,
  capacity_m3_min: null,
  capacity_m3_max: null,
  max_dimensions_cm: null,
  number_of_wheels: 4,
  requires_special_licence: false,
  requires_equipment: [],
  display_order: 1,
  is_active: true,
};

const validValues = {
  country_id: null,
  code: 'pickup_van',
  name: 'Pickup van',
  description: '',
  icon_url: '',
  capacity_kg_min: 500,
  capacity_kg_max: 1500,
  capacity_m3_min: null,
  capacity_m3_max: null,
  max_dimensions_cm: null,
  number_of_wheels: 4,
  requires_special_licence: false,
  requires_equipment: [],
  display_order: 1,
  is_active: true,
};

function setup(options?: {
  handler?: MockHandler;
  rpcHandler?: MockRpcHandler;
  permissions?: string[];
}) {
  permissionState.permissions = options?.permissions ?? ['manage_vehicle_catalog'];

  currentClient = createMockClient(
    options?.handler ??
      (() => ({
        data: [],
        error: null,
        count: 0,
      })),
    options?.rpcHandler ??
      ((name) => {
        if (name === 'admin_config_reference_counts') return { data: {}, error: null };
        return { data: null, error: null };
      }),
  );
}

describe('vehicle type server actions', () => {
  beforeEach(() => {
    setup();
  });

  it('creates a vehicle type and records the action in the audit trail', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'insert') {
          return { data: { id: VEHICLE_TYPE_ID }, error: null };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createVehicleType(validValues);

    expect(result.success).toBe(true);

    const insert = requestFor(currentClient, 'vehicle_types', 'insert');
    expect(insert).toBeDefined();
    expect(insert?.payload).toMatchObject({
      code: 'pickup_van',
      name: 'Pickup van',
      capacity_kg_min: 500,
      capacity_kg_max: 1500,
      country_id: null,
      is_active: true,
    });

    // The console action trail is written for every mutation.
    const log = currentClient.rpcCalls.find((call) => call.name === 'admin_log_action');
    expect(log).toBeDefined();
    expect(log?.args).toMatchObject({
      p_action: 'vehicle_types.created',
      p_entity_type: 'vehicle_types',
      p_entity_id: VEHICLE_TYPE_ID,
      p_permission_used: 'manage_vehicle_catalog',
    });
  });

  it('refuses to create a vehicle type without a code or a name', async () => {
    const actions = await loadActions();
    const result = await actions.createVehicleType({
      ...validValues,
      code: '',
      name: '',
    });

    expect(result.success).toBe(false);
    expect(result.fieldErrors).toMatchObject({
      code: expect.any(String),
      name: expect.any(String),
    });
    expect(requestFor(currentClient, 'vehicle_types', 'insert')).toBeUndefined();
  });

  it('refuses a maximum capacity below the minimum', async () => {
    const actions = await loadActions();
    const result = await actions.createVehicleType({
      ...validValues,
      capacity_kg_min: 1500,
      capacity_kg_max: 500,
    });

    expect(result.success).toBe(false);
    expect(result.fieldErrors?.capacity_kg_max).toMatch(/not be smaller/i);
  });

  it('refuses a code that is already used in the same country', async () => {
    setup({
      handler: (request) => {
        // The uniqueness probe finds the existing row.
        if (request.operation === 'select' && request.filters.length > 0) {
          return { data: [{ id: VEHICLE_TYPE_ID }], error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createVehicleType(validValues);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/already uses this code/i);
    expect(requestFor(currentClient, 'vehicle_types', 'insert')).toBeUndefined();
  });

  it('updates a vehicle type and records only the changed fields', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: vehicleTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.updateVehicleType(VEHICLE_TYPE_ID, {
      ...validValues,
      name: 'Pickup van (large)',
    });

    expect(result.success).toBe(true);

    const update = requestFor(currentClient, 'vehicle_types', 'update');
    expect(update?.payload).toMatchObject({ name: 'Pickup van (large)' });

    const log = currentClient.rpcCalls.find((call) => call.name === 'admin_log_action');
    expect(log?.args.p_action).toBe('vehicle_types.updated');
    expect((log?.args.p_old_value as Record<string, unknown>).name).toBe('Pickup van (large)');
  });

  it('deactivates a vehicle type with a soft delete', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: vehicleTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateVehicleType(VEHICLE_TYPE_ID, 'obsolete');

    expect(result.success).toBe(true);

    const update = requestFor(currentClient, 'vehicle_types', 'update');
    expect(update?.payload).toEqual({ is_active: false });

    const log = currentClient.rpcCalls.find((call) => call.name === 'admin_log_action');
    expect(log?.args.p_action).toBe('vehicle_types.deactivated');
  });

  it('refuses to deactivate a vehicle type that active vehicles still use', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: vehicleTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
      rpcHandler: (name) => {
        if (name === 'admin_config_reference_counts') {
          return { data: { vehicles: 3, pricing_plans: 1 }, error: null };
        }
        return { data: null, error: null };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateVehicleType(VEHICLE_TYPE_ID, 'obsolete');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/3 active vehicles/i);
    expect(requestFor(currentClient, 'vehicle_types', 'update')).toBeUndefined();
  });

  it('refuses every action when the caller has no configuration permission', async () => {
    setup({ permissions: [] });

    const actions = await loadActions();

    const created = await actions.createVehicleType(validValues);
    expect(created.success).toBe(false);
    expect(created.error).toMatch(/permission/i);

    const updated = await actions.updateVehicleType(VEHICLE_TYPE_ID, validValues);
    expect(updated.success).toBe(false);

    const deactivated = await actions.deactivateVehicleType(VEHICLE_TYPE_ID, 'because');
    expect(deactivated.success).toBe(false);

    // Nothing was written.
    expect(requestsFor(currentClient, 'vehicle_types')).toHaveLength(0);
  });

  it('lists the vehicle types with the search and the page size applied', async () => {
    setup({
      handler: () => ({
        data: [vehicleTypeRow],
        error: null,
        count: 1,
      }),
    });

    const actions = await loadActions();
    const result = await actions.listVehicleTypes({
      search: 'pickup',
      status: 'active',
      page: 2,
      pageSize: 10,
    });

    expect(result.success).toBe(true);
    expect(result.total).toBe(1);
    expect(result.page).toBe(2);

    const select = requestsFor(currentClient, 'vehicle_types')[0];
    const orClause = select.filters.find((filter) => filter.operator === 'or');
    expect(orClause?.value).toMatch(/code\.ilike\.\*pickup\*/);
    expect(select.filters).toContainEqual({
      column: 'is_active',
      operator: 'eq',
      value: true,
    });
    expect(select.range).toEqual({ from: 10, to: 19 });
  });
});
