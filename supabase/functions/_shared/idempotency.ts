import { InternalError } from './errors.ts';
import { serviceClient, type SupabaseClient } from './db.ts';

export interface IdempotencyRecord {
  response: unknown;
}

export interface IdempotencyStore {
  get(key: string, scope: string): Promise<IdempotencyRecord | null>;
  put(key: string, scope: string, response: unknown, requestHash?: string): Promise<void>;
}

export class SupabaseIdempotencyStore implements IdempotencyStore {
  constructor(private readonly client: SupabaseClient = serviceClient()) {}

  async get(key: string, scope: string): Promise<IdempotencyRecord | null> {
    const { data, error } = await this.client
      .from('idempotency_keys')
      .select('response')
      .eq('key', key)
      .eq('scope', scope)
      .gt('expires_at', new Date().toISOString())
      .maybeSingle();

    if (error) throw new InternalError('Idempotency lookup failed', { type: 'idempotency_lookup' });
    if (!data) return null;
    return { response: data.response };
  }

  async put(
    key: string,
    scope: string,
    response: unknown,
    requestHash?: string,
  ): Promise<void> {
    const { error } = await this.client.from('idempotency_keys').upsert(
      {
        key,
        scope,
        request_hash: requestHash ?? null,
        response,
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1_000).toISOString(),
      },
      { onConflict: 'key,scope', ignoreDuplicates: true },
    );

    if (error) throw new InternalError('Idempotency store failed', { type: 'idempotency_store' });
  }
}

export function getIdempotencyKey(req: Request): string | null {
  const value = req.headers.get('x-idempotency-key')?.trim();
  return value && value.length > 0 ? value : null;
}

export function checkIdempotencyKey(
  key: string,
  scope: string,
  store: IdempotencyStore = new SupabaseIdempotencyStore(),
): Promise<IdempotencyRecord | null> {
  return store.get(key, scope);
}

export function storeIdempotencyKey(
  key: string,
  scope: string,
  result: unknown,
  requestHash?: string,
  store: IdempotencyStore = new SupabaseIdempotencyStore(),
): Promise<void> {
  return store.put(key, scope, result, requestHash);
}

export async function hashRequest(value: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
