import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import { assertSupabaseEnv, supabaseAnonKey, supabaseUrl } from './config';

export async function createClient() {
  assertSupabaseEnv();
  const cookieStore = await cookies();

  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Server Components cannot set cookies. Middleware refreshes the
          // session, so this is safe to ignore here.
        }
      },
    },
  });
}
