import { createClient } from '@supabase/supabase-js';
import { inject } from 'vitest';

declare module 'vitest' {
  export interface ProvidedContext { adminAccessToken: string }
}

export function verifiedAdmin(config: { url: string; anonKey: string }) {
  const token = inject('adminAccessToken');
  return createClient(config.url, config.anonKey, { accessToken: async () => token });
}
