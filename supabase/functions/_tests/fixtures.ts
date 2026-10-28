// deno-lint-ignore-file require-await
import type { AuthDeps, ProfileRow } from '../_shared/auth.ts';
import type { SupabaseClient } from '../_shared/db.ts';

export function base64Url(value: string): string {
  return btoa(value).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function makeJwt(payload: Record<string, unknown> = {}): string {
  return [
    base64Url(JSON.stringify({ alg: 'none', typ: 'JWT' })),
    base64Url(JSON.stringify({ user_role: 'customer', country_id: null, ...payload })),
    'test-signature',
  ].join('.');
}

export function jsonRequest(
  url: string,
  options: {
    method?: string;
    body?: unknown;
    token?: string | null;
    headers?: Record<string, string>;
  } = {},
): Request {
  const headers = new Headers(options.headers);
  if (options.body !== undefined) headers.set('content-type', 'application/json');
  if (options.token !== null) {
    headers.set('authorization', `Bearer ${options.token ?? makeJwt()}`);
  }
  return new Request(url, {
    method: options.method ?? 'POST',
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
}

export function rawRequest(
  url: string,
  rawBody: string,
  headers: Record<string, string> = {},
): Request {
  return new Request(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: rawBody,
  });
}

export function fakeAuthDeps(
  overrides: Partial<AuthDeps> = {},
  profile: Partial<ProfileRow> = {},
): AuthDeps {
  const service = {} as SupabaseClient;
  return {
    service,
    userClient: () => service,
    verifyToken: async (
      token,
    ) => (token.includes('.') ? { id: '00000000-0000-4000-8000-000000000001' } : null),
    loadProfile: async (id) => ({
      id,
      primary_role: 'customer',
      default_country_id: null,
      is_active: true,
      ...profile,
    }),
    checkPermission: async () => true,
    getCronSecret: async () => 'test-cron-secret',
    ...overrides,
  };
}
