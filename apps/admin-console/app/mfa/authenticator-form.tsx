'use client';

import { useState } from 'react';
import { getBrowserClient } from '@/lib/supabase/client';

export function AuthenticatorForm({ factors }: { factors: { id: string; label: string }[] }) {
  const [id, setId] = useState(factors[0]?.id ?? '');
  const [setupKey, setSetupKey] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (busy) return;
    setError('');
    setBusy(true);
    try {
      const mfa = getBrowserClient().auth.mfa;
      if (!id) {
        const result = await mfa.enroll({ factorType: 'totp', issuer: 'SafeShift' });
        if (result.error) throw result.error;
        setId(result.data.id);
        setSetupKey(result.data.totp.secret);
      } else {
        const result = await mfa.challengeAndVerify({ factorId: id, code });
        if (result.error) throw result.error;
        window.location.replace('/dashboard');
      }
    } catch {
      setError(id ? 'Verification failed. Enter a current six-digit code and try again.' : 'Could not set up the authenticator. Try again.');
    } finally {
      setBusy(false);
    }
  }
  return <form className="form" onSubmit={submit}>
    {factors.length > 1 && <label className="field">Authenticator<select className="input" value={id} onChange={e=>setId(e.target.value)}>
      {factors.map(f=><option value={f.id} key={f.id}>{f.label}</option>)}
    </select></label>}
    {setupKey && <p>Add a time-based account named SafeShift in your authenticator app using this setup key. <code>{setupKey}</code></p>}
    {id && <label className="field">Authenticator code<input className="input" value={code} onChange={e=>setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} required /></label>}
    {error && <p className="notice notice-error" role="alert">{error}</p>}
    <button className="btn btn-primary" disabled={busy}>{id ? 'Verify code' : 'Set up authenticator'}</button>
  </form>;
}
