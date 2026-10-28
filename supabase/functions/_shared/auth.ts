import { ForbiddenError, UnauthorizedError } from './errors.ts';
import { serviceClient, type SupabaseClient, userClient } from './db.ts';
import { readOptionalSecret } from './vault.ts';
import type { AuthContext } from './types/index.ts';

export interface ProfileRow {
  id: string;
  primary_role: string;
  default_country_id: string | null;
  is_active: boolean;
}

export interface AuthDeps {
  service: SupabaseClient;
  userClient: (jwt: string) => SupabaseClient;
  verifyToken: (token: string) => Promise<{ id: string } | null>;
  loadProfile: (id: string) => Promise<ProfileRow | null>;
  checkPermission: (jwt: string, permissionKey: string) => Promise<boolean>;
  getCronSecret: () => Promise<string | null>;
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  const part = token.split('.')[1];
  if (!part) throw new UnauthorizedError('Malformed bearer token');

  const normalized = part.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);

  try {
    return JSON.parse(atob(padded)) as Record<string, unknown>;
  } catch {
    throw new UnauthorizedError('Malformed bearer token');
  }
}

export function defaultAuthDeps(): AuthDeps {
  const service = serviceClient();
  return {
    service,
    userClient,
    verifyToken: async (token) => {
      const { data, error } = await service.auth.getUser(token);
      if (error || !data.user) return null;
      return { id: data.user.id };
    },
    loadProfile: async (id) => {
      const { data, error } = await service
        .from('profiles')
        .select('id, primary_role, default_country_id, is_active')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      return (data as ProfileRow | null) ?? null;
    },
    checkPermission: async (jwt, permissionKey) => {
      const { data, error } = await userClient(jwt).rpc('has_permission', {
        permission_key: permissionKey,
      });
      if (error) throw error;
      return data === true;
    },
    getCronSecret: () => readOptionalSecret('CRON_SECRET', service),
  };
}

export function getBearerToken(req: Request): string | null {
  const header = req.headers.get('authorization');
  if (!header) return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

/**
 * Validate a Supabase Auth JWT, load the authoritative profile, and evaluate
 * the requested permissions through public.has_permission().
 */
export async function requireUser(
  req: Request,
  permissionKeys: string[] = [],
  deps: AuthDeps = defaultAuthDeps(),
): Promise<AuthContext> {
  const token = getBearerToken(req);
  if (!token) throw new UnauthorizedError('Missing Authorization bearer token');

  const user = await deps.verifyToken(token);
  if (!user) throw new UnauthorizedError('Invalid or expired bearer token');

  const claims = decodeJwtPayload(token);
  const profile = await deps.loadProfile(user.id);
  if (!profile) throw new UnauthorizedError('Profile not found');
  if (!profile.is_active) throw new UnauthorizedError('Profile is inactive');

  const permissions: string[] = [];
  for (const key of new Set(permissionKeys)) {
    if (await deps.checkPermission(token, key)) permissions.push(key);
  }

  return {
    userId: user.id,
    // The profile is the authoritative source. Supabase JWTs carry
    // role=authenticated and must not be mistaken for the application role.
    role: profile.primary_role,
    countryId: profile.default_country_id,
    permissions,
    token,
    claims,
  };
}

export async function requireAdmin(
  req: Request,
  permissionKey: string,
  deps: AuthDeps = defaultAuthDeps(),
): Promise<AuthContext> {
  const auth = await requireUser(req, [permissionKey], deps);
  if (!auth.permissions.includes(permissionKey)) {
    throw new ForbiddenError(`Permission ${permissionKey} required`);
  }
  return auth;
}

/**
 * Scheduled functions use a shared cron secret, never a user JWT.
 */
export async function requireServiceRole(
  req: Request,
  deps: AuthDeps = defaultAuthDeps(),
): Promise<{ source: 'cron_secret' }> {
  const provided = req.headers.get('x-cron-secret');
  const expected = await deps.getCronSecret();
  if (!provided || !expected || !timingSafeEqual(provided, expected)) {
    throw new UnauthorizedError('Invalid cron secret');
  }
  return { source: 'cron_secret' };
}

export async function requireInternalSecret(
  req: Request,
  deps: AuthDeps = defaultAuthDeps(),
): Promise<void> {
  const provided = req.headers.get('x-internal-secret');
  const expected = await readOptionalSecret('INTERNAL_FUNCTION_SECRET', deps.service);
  if (!provided || !expected || !timingSafeEqual(provided, expected)) {
    throw new UnauthorizedError('Invalid internal function secret');
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function headerSignature(req: Request, provider: string): string | null {
  const names: Record<string, string[]> = {
    selcom: ['x-selcom-signature', 'x-signature', 'x-webhook-signature'],
    flutterwave: ['verif-hash', 'x-flutterwave-signature'],
    beem: ['x-beem-signature', 'x-signature'],
  };
  for (const name of names[provider] ?? ['x-signature']) {
    const value = req.headers.get(name);
    if (value) return value.trim();
  }
  return null;
}

async function hmacSha256Hex(rawBody: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export async function verifyWebhookSignature(
  req: Request,
  provider: string,
  secret: string,
  rawBody: string,
): Promise<boolean> {
  const provided = headerSignature(req, provider);
  if (!provided) return false;

  if (provider === 'flutterwave' && req.headers.get('verif-hash')) {
    return timingSafeEqual(provided, secret);
  }

  const expected = await hmacSha256Hex(rawBody, secret);
  return timingSafeEqual(provided.toLowerCase(), expected.toLowerCase());
}

export async function requireWebhookSignature(
  req: Request,
  provider: string,
  secret: string,
  rawBody: string,
): Promise<void> {
  if (!(await verifyWebhookSignature(req, provider, secret, rawBody))) {
    throw new UnauthorizedError('Invalid webhook signature');
  }
}

export function getClientIp(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0].trim();
  return (
    req.headers.get('cf-connecting-ip') ??
      req.headers.get('x-real-ip') ??
      req.headers.get('x-client-ip') ??
      'unknown'
  );
}
