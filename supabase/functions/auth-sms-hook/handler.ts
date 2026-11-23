import { structuredLog } from '../_shared/logger.ts';
import { mesejiClient } from '../_shared/provider_factory.ts';
import type { MesejiClient } from '../_shared/providers/meseji.ts';
import { readOptionalSecret } from '../_shared/vault.ts';

/**
 * Supabase Auth "Send SMS" hook. Every phone OTP (sign-in, sign-up, phone
 * change) is delivered through Meseji instead of a built-in Auth SMS provider.
 *
 * Auth signs the request with Standard Webhooks. The secret is configured as
 * `SEND_SMS_HOOK_SECRET` in the form `v1,whsec_<base64>`, exactly as the
 * Supabase dashboard shows it.
 */
export interface AuthSmsHookDeps {
  secret?: string | null;
  client?: MesejiClient;
  now?: () => number;
}

interface HookPayload {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string };
}

const TOLERANCE_SECONDS = 5 * 60;

function hookError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function signStandardWebhook(
  secret: string,
  id: string,
  timestamp: string,
  body: string,
): Promise<string> {
  const raw = secret.replace(/^v1,/, '').replace(/^whsec_/, '');
  const key = await crypto.subtle.importKey(
    'raw',
    decodeBase64(raw),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${id}.${timestamp}.${body}`),
  );
  return btoa(String.fromCharCode(...new Uint8Array(mac)));
}

async function verify(req: Request, body: string, secret: string, now: number): Promise<boolean> {
  const id = req.headers.get('webhook-id');
  const timestamp = req.headers.get('webhook-timestamp');
  const signatures = req.headers.get('webhook-signature');
  if (!id || !timestamp || !signatures) return false;

  const sentAt = Number(timestamp);
  if (!Number.isFinite(sentAt) || Math.abs(now / 1000 - sentAt) > TOLERANCE_SECONDS) return false;

  const expected = await signStandardWebhook(secret, id, timestamp, body);
  return signatures
    .split(' ')
    .map((entry) => entry.split(',', 2))
    .some(([version, signature]) =>
      version === 'v1' && constantTimeEqual(signature ?? '', expected)
    );
}

export function otpMessage(otp: string): string {
  return `${otp} is your SafeShift verification code. Do not share it with anyone.`;
}

export async function handle(req: Request, deps: AuthSmsHookDeps = {}): Promise<Response> {
  if (req.method !== 'POST') return hookError(405, 'Method not allowed');

  const secret = deps.secret !== undefined
    ? deps.secret
    : await readOptionalSecret('SEND_SMS_HOOK_SECRET');
  if (!secret) return hookError(500, 'SMS hook secret is not configured');

  const body = await req.text();
  if (!(await verify(req, body, secret, (deps.now ?? Date.now)()))) {
    return hookError(401, 'Invalid webhook signature');
  }

  let payload: HookPayload;
  try {
    payload = JSON.parse(body) as HookPayload;
  } catch {
    return hookError(400, 'Invalid JSON payload');
  }

  const phone = payload.user?.phone?.trim();
  const otp = payload.sms?.otp?.trim();
  if (!phone || !otp) return hookError(400, 'Phone and OTP are required');

  try {
    const client = deps.client ?? (await mesejiClient());
    await client.sendSms(phone, '', otpMessage(otp), payload.user?.id ?? 'auth-otp');
    return new Response('{}', { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (error) {
    // Never log the phone number or the code.
    structuredLog('error', 'auth-sms-hook', 'auth-otp', 'otp_sms_failed', {
      error_type: error instanceof Error ? error.name : 'unknown',
    });
    return hookError(502, 'Could not send the verification code. Please try again.');
  }
}
