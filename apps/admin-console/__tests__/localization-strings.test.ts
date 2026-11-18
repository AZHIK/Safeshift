import { beforeEach, describe, expect, it, vi } from 'vitest';

import { localizationStrings } from '@/lib/configuration/resources';

import { createMockClient, requestsFor, type MockClient } from './helpers/mock-supabase';

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));

vi.mock('@/lib/configuration/guard', () => ({
  getCallerPermissions: vi.fn(async () => ({
    permissions: new Set(['manage_localization']),
    roles: [],
    isSuperAdmin: false,
  })),
  hasPermission: vi.fn(async () => true),
  canManageConfiguration: vi.fn(async () => true),
  requireConfigurationPermission: vi.fn(async () => ({
    session: { userId: 'admin-1', email: null, name: 'Admin', role: 'super_admin' },
    caller: {
      permissions: new Set(['manage_localization']),
      roles: [],
      isSuperAdmin: false,
    },
  })),
}));

let currentClient: MockClient;

vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(async () => currentClient),
}));

/** The strings the catalogue holds: two languages, one key missing a language. */
const strings = [
  { namespace: 'booking', key: 'submit', language_id: 'lang-en' },
  { namespace: 'booking', key: 'submit', language_id: 'lang-sw' },
  { namespace: 'booking', key: 'cancel', language_id: 'lang-en' },
  { namespace: 'booking', key: 'cancel', language_id: 'lang-sw' },
  { namespace: 'errors', key: 'network', language_id: 'lang-en' },
];

function setup() {
  currentClient = createMockClient((request) => {
    // The coverage probe reads the whole catalogue.
    if (request.operation === 'select' && request.limit === 5000) {
      return { data: strings, error: null, count: strings.length };
    }
    return { data: [], error: null, count: 0 };
  });
}

describe('localization strings', () => {
  beforeEach(() => {
    setup();
  });

  it('groups the list by namespace', () => {
    expect(localizationStrings.groupBy).toBe('namespace');
  });

  it('offers a missing translations filter', () => {
    const filter = localizationStrings.filters?.find((entry) => entry.name === 'translations');
    expect(filter).toBeDefined();
    expect(filter?.options?.map((option) => option.value)).toContain('missing');
  });

  it('does not narrow the list when the filter is off', async () => {
    const actions =
      await import('@/app/(console)/settings/configuration/localization-strings/actions');
    await actions.listLocalizationStrings({ page: 1, pageSize: 25 });

    const select = requestsFor(currentClient, 'localization_strings')[0];
    const orClauses = select.filters.filter((filter) => filter.operator === 'or');
    expect(orClauses).toHaveLength(0);
  });

  it('narrows the list to the keys that are missing a language', async () => {
    const actions =
      await import('@/app/(console)/settings/configuration/localization-strings/actions');
    await actions.listLocalizationStrings({
      page: 1,
      pageSize: 25,
      extra: { translations: 'missing' },
    });

    const select = requestsFor(currentClient, 'localization_strings')[0];
    const orClauses = select.filters.filter((filter) => filter.operator === 'or');
    expect(orClauses).toHaveLength(1);

    // 'errors.network' exists in one language out of two, so it is incomplete.
    // 'booking.submit' and 'booking.cancel' exist in both.
    expect(String(orClauses[0].value)).toContain('namespace.eq.errors,key.eq.network');
    expect(String(orClauses[0].value)).not.toContain('key.eq.submit');
  });

  it('matches nothing when every key is translated', async () => {
    currentClient = createMockClient((request) => {
      if (request.operation === 'select' && request.limit === 5000) {
        return {
          data: [
            { namespace: 'booking', key: 'submit', language_id: 'lang-en' },
            { namespace: 'booking', key: 'submit', language_id: 'lang-sw' },
          ],
          error: null,
          count: 2,
        };
      }
      return { data: [], error: null, count: 0 };
    });

    const actions =
      await import('@/app/(console)/settings/configuration/localization-strings/actions');
    await actions.listLocalizationStrings({
      page: 1,
      pageSize: 25,
      extra: { translations: 'missing' },
    });

    const select = requestsFor(currentClient, 'localization_strings')[0];
    const orClauses = select.filters.filter((filter) => filter.operator === 'or');
    expect(String(orClauses[0].value)).toContain('__no_missing_translations__');
  });
});
