import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  createMockClient,
  requestFor,
  requestsFor,
  type MockClient,
  type MockHandler,
  type MockRpcHandler,
} from './helpers/mock-supabase';

const CARGO_TYPE_ID = 'cccccccc-3333-4333-8333-333333333333';
const TANZANIA_ID = 'dddddddd-4444-4444-8444-444444444444';

type PermissionSet = {
  permissions: string[];
};

const permissionState: PermissionSet = { permissions: [] };

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));

vi.mock('@/lib/configuration/guard', () => ({
  getCallerPermissions: vi.fn(async () => ({
    permissions: new Set(permissionState.permissions),
    roles: [],
    isSuperAdmin: false,
  })),
  hasPermission: vi.fn(async (permission: string) =>
    permissionState.permissions.includes(permission),
  ),
  canManageConfiguration: vi.fn(async () => permissionState.permissions.length > 0),
  requireConfigurationPermission: vi.fn(async () => ({
    session: { userId: 'admin-1', email: null, name: 'Admin', role: 'operations_admin' },
    caller: {
      permissions: new Set(permissionState.permissions),
      roles: [],
      isSuperAdmin: false,
    },
  })),
}));

let currentClient: MockClient;

vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(async () => currentClient),
}));

async function loadActions() {
  return import('@/app/(console)/settings/configuration/cargo-types/actions');
}

const cargoTypeRow = {
  id: CARGO_TYPE_ID,
  country_id: TANZANIA_ID,
  category_id: null,
  code: 'furniture',
  name: 'Furniture',
  description: null,
  icon_url: null,
  requires_special_handling: false,
  requires_declared_value: true,
  requires_insurance: false,
  allowed_vehicle_type_codes: ['pickup_van'],
  prohibited_vehicle_type_codes: [],
  max_value_tzs: 5000000,
  display_order: 2,
  is_active: true,
};

const validValues = {
  country_id: TANZANIA_ID,
  category_id: null,
  code: 'furniture',
  name: 'Furniture',
  description: '',
  icon_url: '',
  requires_special_handling: false,
  requires_declared_value: true,
  requires_insurance: false,
  allowed_vehicle_type_codes: ['pickup_van'],
  prohibited_vehicle_type_codes: [],
  max_value_tzs: 5000000,
  display_order: 2,
  is_active: true,
};

function setup(options?: {
  handler?: MockHandler;
  rpcHandler?: MockRpcHandler;
  permissions?: string[];
}) {
  permissionState.permissions = options?.permissions ?? ['manage_cargo_catalog'];

  currentClient = createMockClient(
    options?.handler ?? (() => ({ data: [], error: null, count: 0 })),
    options?.rpcHandler ??
      ((name) => {
        if (name === 'admin_config_reference_counts') return { data: {}, error: null };
        return { data: null, error: null };
      }),
  );
}

describe('cargo type server actions', () => {
  beforeEach(() => {
    setup();
  });

  it('creates a cargo type scoped to a country', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'insert') return { data: { id: CARGO_TYPE_ID }, error: null };
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createCargoType(validValues);

    expect(result.success).toBe(true);

    const insert = requestFor(currentClient, 'cargo_types', 'insert');
    expect(insert?.payload).toMatchObject({
      code: 'furniture',
      name: 'Furniture',
      country_id: TANZANIA_ID,
      requires_declared_value: true,
      allowed_vehicle_type_codes: ['pickup_van'],
      is_active: true,
    });

    const log = currentClient.rpcCalls.find((call) => call.name === 'admin_log_action');
    expect(log?.args).toMatchObject({
      p_action: 'cargo_types.created',
      p_entity_type: 'cargo_types',
      p_permission_used: 'manage_cargo_catalog',
    });
  });

  it('creates a cargo type that applies to every country', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'insert') return { data: { id: CARGO_TYPE_ID }, error: null };
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createCargoType({ ...validValues, country_id: null });

    expect(result.success).toBe(true);
    expect(requestFor(currentClient, 'cargo_types', 'insert')?.payload).toMatchObject({
      country_id: null,
    });
  });

  it('refuses a cargo type without a code', async () => {
    const actions = await loadActions();
    const result = await actions.createCargoType({ ...validValues, code: '' });

    expect(result.success).toBe(false);
    expect(result.fieldErrors?.code).toMatch(/required/i);
    expect(requestFor(currentClient, 'cargo_types', 'insert')).toBeUndefined();
  });

  it('refuses a code that is already used in the same country', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select' && request.filters.length > 0) {
          return { data: [{ id: CARGO_TYPE_ID }], error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createCargoType(validValues);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/already uses this code/i);
  });

  it('updates a cargo type', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: cargoTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.updateCargoType(CARGO_TYPE_ID, {
      ...validValues,
      name: 'Furniture and fittings',
    });

    expect(result.success).toBe(true);
    expect(requestFor(currentClient, 'cargo_types', 'update')?.payload).toMatchObject({
      name: 'Furniture and fittings',
    });
  });

  it('deactivates a cargo type without deleting the row', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: cargoTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateCargoType(CARGO_TYPE_ID, 'no longer accepted');

    expect(result.success).toBe(true);
    expect(requestFor(currentClient, 'cargo_types', 'update')?.payload).toEqual({
      is_active: false,
    });
    expect(requestFor(currentClient, 'cargo_types', 'delete')).toBeUndefined();
  });

  it('refuses to deactivate a cargo type that quote requests still reference', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: cargoTypeRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
      rpcHandler: (name) => {
        if (name === 'admin_config_reference_counts') {
          return { data: { quote_requests: 12 }, error: null };
        }
        return { data: null, error: null };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateCargoType(CARGO_TYPE_ID, 'no longer accepted');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/12 quote requests/i);
    expect(requestFor(currentClient, 'cargo_types', 'update')).toBeUndefined();
  });

  it('refuses every action when the caller cannot manage the cargo catalogue', async () => {
    setup({ permissions: ['manage_vehicle_catalog'] });

    const actions = await loadActions();

    const created = await actions.createCargoType(validValues);
    expect(created.success).toBe(false);
    expect(created.error).toMatch(/permission/i);

    expect(requestsFor(currentClient, 'cargo_types')).toHaveLength(0);
  });

  it('filters the list by country', async () => {
    setup({
      handler: () => ({ data: [cargoTypeRow], error: null, count: 1 }),
    });

    const actions = await loadActions();
    const result = await actions.listCargoTypes({ country: TANZANIA_ID, page: 1, pageSize: 25 });

    expect(result.success).toBe(true);
    const select = requestsFor(currentClient, 'cargo_types')[0];
    expect(select.filters).toContainEqual({
      column: 'country_id',
      operator: 'eq',
      value: TANZANIA_ID,
    });
  });
});
