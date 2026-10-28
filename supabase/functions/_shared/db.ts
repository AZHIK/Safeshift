import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.49.1';

export type { SupabaseClient };

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

/**
 * Service-role client. RLS is bypassed. Only webhooks, scheduled jobs, and
 * post-authorization server code may use this client.
 */
export function serviceClient(): SupabaseClient {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-client-info': 'safeshift-edge-function' } },
  });
}

/**
 * User-scoped client. Every query is evaluated by RLS as the JWT subject.
 */
export function userClient(jwt: string): SupabaseClient {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_ANON_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: {
        Authorization: `Bearer ${jwt}`,
        'x-client-info': 'safeshift-edge-function',
      },
    },
  });
}
