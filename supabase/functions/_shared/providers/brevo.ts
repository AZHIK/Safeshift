import type { EmailResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

/**
 * Brevo (https://www.brevo.com) transactional email client. SafeShift's only
 * email provider.
 *
 * API: `POST {baseUrl}/smtp/email` with an `api-key` header. The sender must
 * be a sender or domain verified in the Brevo account.
 */
export interface BrevoConfig {
  apiKey: string;
  /** "SafeShift <noreply@example.com>" or a bare address. */
  from: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export const BREVO_DEFAULT_BASE_URL = 'https://api.brevo.com/v3';

/** Splits "Name <email>" into Brevo's { name, email } sender shape. */
export function parseSender(value: string): { name?: string; email: string } {
  const match = value.trim().match(/^(.*?)\s*<([^<>\s]+@[^<>\s]+)>$/);
  if (match) {
    const name = match[1].replace(/^"|"$/g, '').trim();
    return name ? { name, email: match[2] } : { email: match[2] };
  }
  return { email: value.trim() };
}

export class BrevoClient {
  private readonly baseUrl: string;
  private readonly config: BrevoConfig;

  constructor(config: BrevoConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? BREVO_DEFAULT_BASE_URL).replace(/\/$/, '');
  }

  async sendEmail(
    to: string,
    from: string,
    subject: string,
    html: string,
    text: string,
    reference: string,
  ): Promise<EmailResult> {
    const { data } = await requestJson<Record<string, unknown>>(
      'brevo',
      `${this.baseUrl}/smtp/email`,
      {
        method: 'POST',
        headers: {
          'api-key': this.config.apiKey,
          'content-type': 'application/json',
          accept: 'application/json',
        },
        body: JSON.stringify({
          sender: parseSender(from || this.config.from),
          to: [{ email: to }],
          subject,
          htmlContent: html,
          textContent: text,
          headers: { 'X-Entity-Ref-ID': reference },
        }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    return {
      provider_message_id: String(data?.messageId ?? reference),
      status: 'sent',
    };
  }
}
