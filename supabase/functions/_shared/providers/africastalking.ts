import type { SmsResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface AfricaSTalkingConfig {
  username: string;
  apiKey: string;
  senderId?: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export class AfricaSTalkingClient {
  private readonly baseUrl: string;
  private readonly config: AfricaSTalkingConfig;

  constructor(config: AfricaSTalkingConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://api.africastalking.com').replace(/\/$/, '');
  }

  private headers(): Record<string, string> {
    return {
      apiKey: this.config.apiKey,
      'content-type': 'application/x-www-form-urlencoded',
      accept: 'application/json',
    };
  }

  async sendSms(to: string, from: string, body: string, reference: string): Promise<SmsResult> {
    const params = new URLSearchParams({
      username: this.config.username,
      to,
      message: body,
      from: from || this.config.senderId || 'SafeShift',
    });

    const { data } = await requestJson<Record<string, unknown>>(
      'africastalking',
      `${this.baseUrl}/version1/messaging`,
      {
        method: 'POST',
        headers: this.headers(),
        body: params.toString(),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const smsData = (data.SMSMessageData ?? data) as Record<string, unknown>;
    const recipients = (smsData.Recipients ?? []) as Array<Record<string, unknown>>;
    const first = recipients[0] ?? {};

    return {
      provider_message_id: String(first.messageId ?? first.message_id ?? reference),
      status: 'sent',
    };
  }

  checkDeliveryStatus(_providerMessageId: string): Promise<{ status: string }> {
    return Promise.resolve({ status: 'unknown' });
  }
}
