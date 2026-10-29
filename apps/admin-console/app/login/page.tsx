import { redirect } from 'next/navigation';

import { loginAction } from '@/app/actions/auth';
import { getAdminSession } from '@/lib/auth';

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const params = await searchParams;
  const session = await getAdminSession();
  if (session) redirect('/dashboard');

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <div className="brand-mark">S</div>
          <div>
            <div className="brand-name" style={{ color: 'var(--ink)' }}>SafeShift</div>
            <div className="brand-sub" style={{ color: 'var(--muted)' }}>Admin console</div>
          </div>
        </div>
        <h1 className="login-title">Sign in</h1>
        <p className="login-sub">For SafeShift staff and fleet owners. Accounts are provisioned by an administrator.</p>
        {params.error ? <div className="notice notice-error">{params.error}</div> : null}
        <form action={loginAction} className="form">
          <input type="hidden" name="next" value={params.next ?? '/dashboard'} />
          <div className="field">
            <label htmlFor="email">Email</label>
            <input className="input" id="email" name="email" type="email" autoComplete="email" required />
          </div>
          <div className="field">
            <label htmlFor="password">Password</label>
            <input className="input" id="password" name="password" type="password" autoComplete="current-password" required />
          </div>
          <button className="btn btn-primary" type="submit" style={{ marginTop: 6 }}>Sign in</button>
        </form>
        <div className="login-hint">
          Seeded local admin: <strong>superadmin@safeshift.local</strong> / <strong>SafeshiftDev!2026</strong>
          <br />
          Fleet owner: <strong>fleet.owner@safeshift.local</strong> / <strong>SafeshiftDev!2026</strong>
        </div>
      </div>
    </div>
  );
}
