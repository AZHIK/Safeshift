'use client';

import { createBrowserClient } from '@supabase/ssr';

import { assertSupabaseEnv, supabaseAnonKey, supabaseUrl } from './config';

let client: ReturnType<typeof createBrowserClient> | undefined;

export function getBrowserClient() {
  assertSupabaseEnv();
  client ??= createBrowserClient(supabaseUrl, supabaseAnonKey);
  return client;
}
