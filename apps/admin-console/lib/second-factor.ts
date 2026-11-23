import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * True when the signed-in session has passed a second factor: an
 * authenticator code (Supabase raises the session to aal2) or an emailed or
 * texted code recorded against this session (public.admin_second_factor_status).
 * The database applies the same rule in private.second_factor_verified().
 */
export async function secondFactorVerified(supabase: SupabaseClient): Promise<boolean> {
  const { data: assurance } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (assurance?.currentLevel === 'aal2') return true;
  const { data, error } = await supabase.rpc('admin_second_factor_status');
  if (error) return false;
  return Boolean((data as { verified?: boolean } | null)?.verified);
}
