import { createClient as createSupabaseClient } from '@supabase/supabase-js';

import { assertSupabaseEnv, supabaseAnonKey, supabaseUrl } from './config';

/** Anonymous client for public, token-scoped read-only pages. */
export function createAnonClient() {
  assertSupabaseEnv();
  return createSupabaseClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
