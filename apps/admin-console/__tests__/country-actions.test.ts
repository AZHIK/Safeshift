import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  createMockClient,
  requestFor,
  type MockClient,
  type MockHandler,
  type MockRpcHandler,
} from './helpers/mock-supabase';

const COUNTRY_ID = 'eeeeeeee-5555-4555-8555-555555555555';
const CURRENCY_ID = 'ffffffff-6666-4666-8666-666666666666';
const LANGUAGE_ID = 'aaaaaaaa-7777-4777-8777-777777777777';

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
  return import('@/app/(console)/settings/configuration/countries/actions');
}

const countryRow = {
  id: COUNTRY_ID,
  iso_code: 'TZ',
  name: 'Tanzania',
  default_currency_id: CURRENCY_ID,
  default_timezone: 'Africa/Dar_es_Salaam',
  default_language_id: LANGUAGE_ID,
  regulatory_framework: 'NTSA',
  tax_registration_required: true,
  is_active: true,
  launched_at: '2026-01-15T00:00:00+00:00',
};

const validValues = {
  iso_code: 'TZ',
  name: 'Tanzania',
  default_currency_id: CURRENCY_ID,
  default_timezone: 'Africa/Dar_es_Salaam',
  default_language_id: LANGUAGE_ID,
  regulatory_framework: 'NTSA',
  tax_registration_required: true,
  launched_at: '2026-01-15',
  is_active: true,
};

function setup(options?: {
  handler?: MockHandler;
  rpcHandler?: MockRpcHandler;
  permissions?: string[];
}) {
  permissionState.permissions = options?.permissions ?? ['manage_countries'];

  currentClient = createMockClient(
    options?.handler ?? (() => ({ data: [], error: null, count: 0 })),
    options?.rpcHandler ??
      ((name) => {
        if (name === 'admin_config_reference_counts') return { data: {}, error: null };
        return { data: null, error: null };
      }),
  );
}

describe('country server actions', () => {
  beforeEach(() => {
    setup();
  });

  it('creates a country', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'insert') return { data: { id: COUNTRY_ID }, error: null };
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createCountry(validValues);

    expect(result.success).toBe(true);

    const insert = requestFor(currentClient, 'countries', 'insert');
    expect(insert?.payload).toMatchObject({
      iso_code: 'TZ',
      name: 'Tanzania',
      default_timezone: 'Africa/Dar_es_Salaam',
      default_currency_id: CURRENCY_ID,
      default_language_id: LANGUAGE_ID,
      regulatory_framework: 'NTSA',
      tax_registration_required: true,
      is_active: true,
    });

    const log = currentClient.rpcCalls.find((call) => call.name === 'admin_log_action');
    expect(log?.args).toMatchObject({
      p_action: 'countries.created',
      p_entity_type: 'countries',
      p_permission_used: 'manage_countries',
    });
  });

  it('refuses a country without an ISO code', async () => {
    const actions = await loadActions();
    const result = await actions.createCountry({ ...validValues, iso_code: '' });

    expect(result.success).toBe(false);
    expect(result.fieldErrors?.iso_code).toMatch(/required/i);
    expect(requestFor(currentClient, 'countries', 'insert')).toBeUndefined();
  });

  it('refuses a lowercase ISO code', async () => {
    const actions = await loadActions();
    const result = await actions.createCountry({ ...validValues, iso_code: 'tz' });

    expect(result.success).toBe(false);
    expect(result.fieldErrors?.iso_code).toMatch(/two-letter uppercase ISO code/i);
    expect(requestFor(currentClient, 'countries', 'insert')).toBeUndefined();
  });

  it('refuses a country without a time zone', async () => {
    const actions = await loadActions();
    const result = await actions.createCountry({ ...validValues, default_timezone: '' });

    expect(result.success).toBe(false);
    expect(result.fieldErrors?.default_timezone).toMatch(/required/i);
    expect(requestFor(currentClient, 'countries', 'insert')).toBeUndefined();
  });

  it('refuses an ISO code that is already used', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select' && request.filters.length > 0) {
          return { data: [{ id: COUNTRY_ID }], error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.createCountry(validValues);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/already uses this ISO code/i);
  });

  it('updates a country', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: countryRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.updateCountry(COUNTRY_ID, {
      ...validValues,
      name: 'United Republic of Tanzania',
    });

    expect(result.success).toBe(true);
    expect(requestFor(currentClient, 'countries', 'update')?.payload).toMatchObject({
      name: 'United Republic of Tanzania',
    });
  });

  it('deactivates a country when nothing references it', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: countryRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateCountry(COUNTRY_ID, 'Market closed');

    expect(result.success).toBe(true);
    expect(requestFor(currentClient, 'countries', 'update')?.payload).toMatchObject({
      is_active: false,
    });
  });

  it('refuses to deactivate a country that live data still points at', async () => {
    setup({
      handler: (request) => {
        if (request.operation === 'select') {
          return { data: countryRow, error: null, count: 1 };
        }
        return { data: [], error: null, count: 0 };
      },
      rpcHandler: (name) => {
        if (name === 'admin_config_reference_counts') {
          return { data: { cities: 3, vehicles: 12 }, error: null };
        }
        return { data: null, error: null };
      },
    });

    const actions = await loadActions();
    const result = await actions.deactivateCountry(COUNTRY_ID, 'Market closed');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/referenced by/i);
    expect(requestFor(currentClient, 'countries', 'update')).toBeUndefined();
  });

  it('refuses every write without the permission', async () => {
    setup({ permissions: [] });

    const actions = await loadActions();
    const created = await actions.createCountry(validValues);
    const updated = await actions.updateCountry(COUNTRY_ID, validValues);
    const deactivated = await actions.deactivateCountry(COUNTRY_ID, 'Closed');

    expect(created.success).toBe(false);
    expect(updated.success).toBe(false);
    expect(deactivated.success).toBe(false);
    expect(created.error).toMatch(/permission/i);
    expect(requestFor(currentClient, 'countries', 'insert')).toBeUndefined();
    expect(requestFor(currentClient, 'countries', 'update')).toBeUndefined();
  });
});
