import { redirect } from 'next/navigation';

import { signOutAction } from '@/app/actions/auth';
import { enabledSecondFactorMethods, secondFactorVerified } from '@/lib/second-factor';
import { createClient } from '@/lib/supabase/server';

import { SecondFactorOptions } from './second-factor-options';

/** Masks for display only; the server never sends codes to the browser. */
function maskEmail(email: string | null): string | null {
  if (!email || !email.includes('@')) return null;
  const [local, domain] = email.split('@');
  return `${local.slice(0, 2)}••••@${domain}`;
}

function maskPhone(phone: string | null): string | null {
  const digits = (phone ?? '').replace(/\D/g, '');
  return digits.length >= 6 ? `+${digits.slice(0, 3)} •••• ${digits.slice(-3)}` : null;
}

export default async function MfaPage() {
  const client = await createClient();
  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) redirect('/login');
  const { data: role } = await client.rpc('admin_console_role');
  if (!role) redirect('/login?error=An active console role is required.');
  if (await secondFactorVerified(client)) redirect('/dashboard');

  const [factors, status] = await Promise.all([client.auth.mfa.listFactors(), client.rpc('admin_second_factor_status')]);
  const info = (status.data ?? {}) as { email?: string | null; phone?: string | null };
  const authenticators = (factors.data?.totp ?? [])
    .filter((f) => f.status === 'verified')
    .map((f) => ({ id: f.id, label: f.friendly_name || 'Authenticator app' }));

  return (
    <main className="login-page">
      <section className="login-card" aria-labelledby="mfa-title">
        <h1 className="login-title" id="mfa-title">
          Verify it&apos;s you
        </h1>
        <p className="login-sub">Console access needs a second step.</p>
        {factors.error ? (
          <p className="notice notice-error" role="alert">
            Could not load your sign-in options. Refresh to try again.
          </p>
        ) : (
          <SecondFactorOptions
            methods={enabledSecondFactorMethods()}
            authenticators={authenticators}
            email={maskEmail(info.email ?? user.email ?? null)}
            phone={maskPhone(info.phone ?? null)}
          />
        )}
        <form action={signOutAction} style={{ marginTop: 16 }}>
          <button className="btn" type="submit">
            Sign out
          </button>
        </form>
      </section>
    </main>
  );
}
