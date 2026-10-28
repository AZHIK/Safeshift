import { InternalError } from './errors.ts';
import { serviceClient, type SupabaseClient } from './db.ts';

const cache = new Map<string, string>();

/**
 * Resolve a provider secret.
 *
 * Local development and Supabase Edge Function secrets are available through
 * Deno.env. Production provider credentials live in Supabase Vault and are read
 * through the service-role-only public.get_vault_secret() RPC.
 */
export async function readSecret(
  name: string,
  client: SupabaseClient = serviceClient(),
): Promise<string> {
  const fromEnv = Deno.env.get(name);
  if (fromEnv) return fromEnv;

  const cached = cache.get(name);
  if (cached) return cached;

  const { data, error } = await client.rpc('get_vault_secret', { p_name: name });
  if (error) {
    throw new InternalError(`Unable to read Vault secret ${name}`, { type: 'vault_read_failed' });
  }
  if (typeof data !== 'string' || data.length === 0) {
    throw new InternalError(`Vault secret ${name} is not configured`, {
      type: 'vault_secret_missing',
    });
  }

  cache.set(name, data);
  return data;
}

export async function readOptionalSecret(
  name: string,
  client: SupabaseClient = serviceClient(),
): Promise<string | null> {
  try {
    return await readSecret(name, client);
  } catch {
    return null;
  }
}

export function clearSecretCache(): void {
  cache.clear();
}
