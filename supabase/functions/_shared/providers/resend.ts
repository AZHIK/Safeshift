import type { EmailResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface ResendConfig {
  apiKey: string;
  from: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export class ResendClient {
  private readonly baseUrl: string;
  private readonly config: ResendConfig;

  constructor(config: ResendConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://api.resend.com').replace(/\/$/, '');
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
      'resend',
      `${this.baseUrl}/emails`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.config.apiKey}`,
          'content-type': 'application/json',
          accept: 'application/json',
        },
        body: JSON.stringify({
          from: from || this.config.from,
          to: [to],
          subject,
          html,
          text,
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
      provider_message_id: String(data.id ?? reference),
      status: 'sent',
    };
  }
}
