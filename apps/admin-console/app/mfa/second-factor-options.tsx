'use client';

import { useEffect, useState } from 'react';

import { getBrowserClient } from '@/lib/supabase/client';

type Method = 'authenticator' | 'sms' | 'email';
type Authenticator = { id: string; label: string };

const CODE_RE = /^\d{6}$/;
const RESEND_SECONDS = 60;

/** Pulls the readable message out of a supabase.functions.invoke error. */
async function functionError(error: unknown): Promise<string> {
  const e = error as { message?: string; context?: { json?: () => Promise<unknown> } };
  try {
    const body = (await e.context?.json?.()) as { error?: { message?: string } } | undefined;
    if (body?.error?.message) return body.error.message;
  } catch {
    // fall through
  }
  return e.message ?? 'Something went wrong. Try again.';
}

function CodeField({ value, onChange, id }: { value: string; onChange: (v: string) => void; id: string }) {
  return (
    <label className="field" htmlFor={id}>
      6-digit code
      <input
        id={id}
        className="input mono"
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, 6))}
        inputMode="numeric"
        autoComplete="one-time-code"
        pattern="[0-9]{6}"
        maxLength={6}
        required
        autoFocus
        style={{ letterSpacing: 6, fontSize: 20, textAlign: 'center' }}
      />
    </label>
  );
}

export function SecondFactorOptions({
  authenticators,
  email,
  phone,
}: {
  authenticators: Authenticator[];
  email: string | null;
  phone: string | null;
}) {
  const methods: { id: Method; label: string; available: boolean }[] = [
    { id: 'authenticator', label: 'Authenticator app', available: true },
    { id: 'sms', label: 'Text message', available: Boolean(phone) },
    { id: 'email', label: 'Email', available: Boolean(email) },
  ];
  const [method, setMethod] = useState<Method>('authenticator');

  return (
    <div className="section-stack" style={{ marginTop: 12 }}>
      <div role="tablist" aria-label="Verification method" className="inline" style={{ gap: 8, flexWrap: 'wrap' }}>
        {methods.map((m) => (
          <button
            key={m.id}
            type="button"
            role="tab"
            aria-selected={method === m.id}
            className={`btn btn-sm${method === m.id ? ' btn-primary' : ''}`}
            onClick={() => setMethod(m.id)}
          >
            {m.label}
          </button>
        ))}
      </div>
      <div role="tabpanel">
        {method === 'authenticator' ? <AuthenticatorMethod authenticators={authenticators} /> : null}
        {method === 'sms' ? (
          phone ? (
            <CodeMethod channel="sms" destination={phone} />
          ) : (
            <p className="small muted">
              No phone number is on your account. Ask an administrator to add one, or use another method.
            </p>
          )
        ) : null}
        {method === 'email' ? (
          email ? (
            <CodeMethod channel="email" destination={email} />
          ) : (
            <p className="small muted">No email address is on your account. Use another method.</p>
          )
        ) : null}
      </div>
    </div>
  );
}

function AuthenticatorMethod({ authenticators }: { authenticators: Authenticator[] }) {
  const [factorId, setFactorId] = useState(authenticators[0]?.id ?? '');
  const [qr, setQr] = useState('');
  const [secret, setSecret] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const enrolling = Boolean(qr);

  async function startSetup() {
    setBusy(true);
    setError('');
    try {
      const mfa = getBrowserClient().auth.mfa;
      // Unfinished earlier setups would block a new one.
      const existing = await mfa.listFactors();
      for (const f of existing.data?.all ?? []) {
        if (f.factor_type === 'totp' && f.status !== 'verified') await mfa.unenroll({ factorId: f.id });
      }
      const result = await mfa.enroll({
        factorType: 'totp',
        issuer: 'SafeShift',
        friendlyName: `Authenticator ${new Date().toISOString().slice(0, 10)}`,
      });
      if (result.error) throw result.error;
      setFactorId(result.data.id);
      setQr(result.data.totp.qr_code);
      setSecret(result.data.totp.secret);
    } catch {
      setError('Could not start the authenticator setup. Try again.');
    } finally {
      setBusy(false);
    }
  }

  async function verify(event: React.FormEvent) {
    event.preventDefault();
    if (!CODE_RE.test(code) || busy) return;
    setBusy(true);
    setError('');
    try {
      const result = await getBrowserClient().auth.mfa.challengeAndVerify({ factorId, code });
      if (result.error) throw result.error;
      window.location.replace('/dashboard');
    } catch {
      setError('That code did not work. Enter the current code from your app.');
      setCode('');
    } finally {
      setBusy(false);
    }
  }

  if (!factorId) {
    return (
      <div className="section-stack">
        <p className="small">
          Use an app such as Google Authenticator, Microsoft Authenticator or Authy. You will scan a QR code once; after
          that, open the app to get a code each time you sign in.
        </p>
        {error ? <p className="notice notice-error" role="alert">{error}</p> : null}
        <button type="button" className="btn btn-primary" onClick={startSetup} disabled={busy}>
          {busy ? 'Preparing…' : 'Set up authenticator app'}
        </button>
      </div>
    );
  }

  return (
    <form className="form" onSubmit={verify}>
      {enrolling ? (
        <div className="section-stack" style={{ alignItems: 'center' }}>
          <p className="small">1. Scan this QR code with your authenticator app.</p>
          {/* Supabase returns the QR code as an SVG data URL. */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={qr}
            alt="QR code to add SafeShift to your authenticator app"
            width={200}
            height={200}
            style={{ background: '#fff', padding: 8, borderRadius: 8 }}
          />
          <details>
            <summary className="small">Can&apos;t scan? Enter this key instead</summary>
            <code className="mono" style={{ wordBreak: 'break-all' }}>
              {secret}
            </code>
          </details>
          <p className="small">2. Enter the 6-digit code the app shows.</p>
        </div>
      ) : authenticators.length > 1 ? (
        <label className="field">
          Authenticator
          <select className="input" value={factorId} onChange={(e) => setFactorId(e.target.value)}>
            {authenticators.map((a) => (
              <option key={a.id} value={a.id}>
                {a.label}
              </option>
            ))}
          </select>
        </label>
      ) : (
        <p className="small">Open your authenticator app and enter the current code for SafeShift.</p>
      )}
      <CodeField id="totp-code" value={code} onChange={setCode} />
      {error ? <p className="notice notice-error" role="alert">{error}</p> : null}
      <button className="btn btn-primary" disabled={busy || !CODE_RE.test(code)}>
        {busy ? 'Verifying…' : enrolling ? 'Finish setup' : 'Verify'}
      </button>
    </form>
  );
}

function CodeMethod({ channel, destination }: { channel: 'sms' | 'email'; destination: string }) {
  const [sentTo, setSentTo] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [wait, setWait] = useState(0);

  useEffect(() => {
    if (wait <= 0) return;
    const timer = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(timer);
  }, [wait]);

  async function send() {
    setBusy(true);
    setError('');
    try {
      const { data, error: invokeError } = await getBrowserClient().functions.invoke('admin-otp', {
        body: { channel },
      });
      if (invokeError) throw new Error(await functionError(invokeError));
      setSentTo((data as { data?: { to?: string } })?.data?.to ?? destination);
      setWait(RESEND_SECONDS);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not send the code.');
    } finally {
      setBusy(false);
    }
  }

  async function verify(event: React.FormEvent) {
    event.preventDefault();
    if (!CODE_RE.test(code) || busy) return;
    setBusy(true);
    setError('');
    try {
      const { data, error: rpcError } = await getBrowserClient().rpc('admin_verify_second_factor', { p_code: code });
      if (rpcError) throw new Error(rpcError.message);
      if (data !== true) {
        setError('That code is not right. Check the latest message and try again.');
        setCode('');
        return;
      }
      window.location.replace('/dashboard');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not verify the code.');
    } finally {
      setBusy(false);
    }
  }

  const what = channel === 'sms' ? 'a text message' : 'an email';
  return (
    <form className="form" onSubmit={verify}>
      {sentTo ? (
        <p className="small" aria-live="polite">
          We sent a code to <strong>{sentTo}</strong>. It expires in 10 minutes.
        </p>
      ) : (
        <p className="small">
          We&apos;ll send {what} with a 6-digit code to <strong>{destination}</strong>.
        </p>
      )}
      {sentTo ? <CodeField id={`${channel}-code`} value={code} onChange={setCode} /> : null}
      {error ? <p className="notice notice-error" role="alert">{error}</p> : null}
      <div className="inline" style={{ gap: 8 }}>
        {sentTo ? (
          <button className="btn btn-primary" disabled={busy || !CODE_RE.test(code)}>
            {busy ? 'Verifying…' : 'Verify'}
          </button>
        ) : null}
        <button type="button" className={`btn${sentTo ? '' : ' btn-primary'}`} onClick={send} disabled={busy || wait > 0}>
          {wait > 0 ? `Resend in ${wait}s` : sentTo ? 'Send a new code' : 'Send code'}
        </button>
      </div>
    </form>
  );
}
