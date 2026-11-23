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

export type SecondFactorMethod = 'authenticator' | 'sms' | 'email';

/**
 * Methods offered on /mfa, from CONSOLE_2FA_METHODS (comma-separated, e.g.
 * "authenticator,sms,email"). Defaults to the authenticator app only: text
 * message and email need MESEJI_API_KEY / BREVO_API_KEY on the project.
 * The authenticator app is always offered so staff can never be locked out.
 */
export function enabledSecondFactorMethods(raw = process.env.CONSOLE_2FA_METHODS): SecondFactorMethod[] {
  const wanted = new Set((raw ?? '').split(',').map((m) => m.trim().toLowerCase()));
  const methods: SecondFactorMethod[] = ['authenticator'];
  if (wanted.has('sms')) methods.push('sms');
  if (wanted.has('email')) methods.push('email');
  return methods;
}
