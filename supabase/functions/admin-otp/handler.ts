import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import {
  AppError,
  ProviderError,
  RateLimitError,
  UnauthorizedError,
  ValidationError,
} from '../_shared/errors.ts';
import { brevoClient, mesejiClient } from '../_shared/provider_factory.ts';
import type { BrevoClient } from '../_shared/providers/brevo.ts';
import type { MesejiClient } from '../_shared/providers/meseji.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

/**
 * Sends a console sign-in code (the email or text-message second factor).
 * The code is issued by public.admin_issue_second_factor_challenge, which only
 * the service role may call, so it never reaches the browser: the admin must
 * read the email (Brevo) or SMS (Meseji).
 *
 * Body: { "channel": "email" | "sms" }
 */
export interface AdminOtpDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  email?: BrevoClient;
  sms?: MesejiClient;
}

type Channel = 'email' | 'sms';

/** "kasimu@example.com" → "ka••••@example.com" */
export function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!domain) return '••••';
  return `${local.slice(0, Math.min(2, local.length))}••••@${domain}`;
}

/** "+255712345678" → "+255 •••• 678" */
export function maskPhone(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 6) return '••••';
  return `+${digits.slice(0, 3)} •••• ${digits.slice(-3)}`;
}

export function codeEmail(code: string): { subject: string; html: string; text: string } {
  const text = `Your SafeShift console sign-in code is ${code}.\n\n` +
    'It expires in 10 minutes. If you did not try to sign in, change your password and tell your administrator.';
  const html = '<div style="font-family:Arial,sans-serif;font-size:15px;color:#1f2937">' +
    '<p>Your SafeShift console sign-in code is:</p>' +
    `<p style="font-size:28px;font-weight:700;letter-spacing:6px">${code}</p>` +
    '<p>It expires in 10 minutes. If you did not try to sign in, change your password and tell your administrator.</p>' +
    '</div>';
  return { subject: `${code} is your SafeShift sign-in code`, html, text };
}

export function codeSms(code: string): string {
  return `${code} is your SafeShift console sign-in code. It expires in 10 minutes. Do not share it.`;
}

async function readChannel(req: Request): Promise<Channel> {
  let body: unknown = {};
  try {
    body = await req.json();
  } catch {
    // No body: default below.
  }
  const channel = (body as { channel?: unknown })?.channel ?? 'email';
  if (channel !== 'email' && channel !== 'sms') {
    throw new ValidationError('channel must be "email" or "sms"');
  }
  return channel;
}

export async function handle(
  req: Request,
  ctx: RequestContext,
  deps: AdminOtpDeps = {},
): Promise<Response> {
  const auth = await requireUser(req, [], deps.auth ?? defaultAuthDeps());
  const sessionId = typeof auth.claims.session_id === 'string' ? auth.claims.session_id : '';
  if (!sessionId) throw new UnauthorizedError('Sign in again before requesting a code');
  const channel = await readChannel(req);

  const service = deps.service ?? serviceClient();
  const { data, error } = await service.rpc('admin_issue_second_factor_challenge', {
    p_profile_id: auth.userId,
    p_session_id: sessionId,
    p_channel: channel,
  });
  if (error) {
    // 53400: a code was sent less than a minute ago.
    if ((error as { code?: string }).code === '53400') throw new RateLimitError(60, error.message);
    throw new AppError(422, 'code_refused', error.message);
  }
  const issued = (Array.isArray(data) ? data[0] : data) as
    | { code?: string; destination?: string }
    | null;
  if (!issued?.code || !issued.destination) {
    throw new AppError(422, 'code_refused', 'No code could be issued');
  }

  try {
    if (channel === 'email') {
      const message = codeEmail(issued.code);
      const client = deps.email ?? (await brevoClient(ctx.requestId));
      await client.sendEmail(
        issued.destination,
        '',
        message.subject,
        message.html,
        message.text,
        `admin-otp:${sessionId}`,
      );
    } else {
      const client = deps.sms ?? (await mesejiClient(ctx.requestId));
      await client.sendSms(issued.destination, '', codeSms(issued.code), `admin-otp:${sessionId}`);
    }
  } catch (sendError) {
    // An unsent code must not stay valid, and the admin may retry at once.
    await service
      .rpc('admin_discard_email_challenge', { p_session_id: sessionId })
      .then(() => undefined, () => undefined);
    if (sendError instanceof AppError) throw sendError;
    throw new ProviderError(channel === 'email' ? 'brevo' : 'meseji', 'The code could not be sent');
  }

  return success({
    sent: true,
    channel,
    to: channel === 'email' ? maskEmail(issued.destination) : maskPhone(issued.destination),
    expires_in_seconds: 600,
  });
}
