import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/actions/auth';
import { createClient } from '@/lib/supabase/server';
import { AuthenticatorForm } from './authenticator-form';

export default async function MfaPage() {
  const client = await createClient();
  const { data: { user } } = await client.auth.getUser();
  if (!user) redirect('/login');
  const { data: role } = await client.rpc('admin_console_role');
  if (!role) redirect('/login?error=An active console role is required.');
  const { data: assurance } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
  if (assurance?.currentLevel === 'aal2') redirect('/dashboard');
  const factors = await client.auth.mfa.listFactors();
  return <main className="login-page"><section className="login-card">
    <h1 className="login-title">Verify your sign-in</h1>
    {factors.error ? <p role="alert">Could not load authenticators. Refresh to try again.</p> :
      <AuthenticatorForm factors={factors.data.totp.map(f => ({ id: f.id, label: f.friendly_name || 'Authenticator' }))} />}
    <form action={signOutAction}><button className="btn" type="submit">Sign out</button></form>
  </section></main>;
}
