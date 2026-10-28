import type { SmsResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface BeemConfig {
  apiKey: string;
  apiSecret: string;
  senderId: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export class BeemClient {
  private readonly baseUrl: string;
  private readonly config: BeemConfig;

  constructor(config: BeemConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://apisms.beem.africa').replace(/\/$/, '');
  }

  private headers(): Record<string, string> {
    return {
      authorization: `Basic ${btoa(`${this.config.apiKey}:${this.config.apiSecret}`)}`,
      'content-type': 'application/json',
      accept: 'application/json',
    };
  }

  async sendSms(to: string, from: string, body: string, reference: string): Promise<SmsResult> {
    const { data } = await requestJson<Record<string, unknown>>(
      'beem',
      `${this.baseUrl}/v1/send`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          source_addr: from || this.config.senderId,
          schedule_time: '',
          encoding: 0,
          message: body,
          recipients: [{ recipient_id: reference, dest_addr: to }],
        }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    return {
      provider_message_id: String(data.message_id ?? data.request_id ?? reference),
      status: 'sent',
    };
  }

  async checkDeliveryStatus(providerMessageId: string): Promise<{ status: string }> {
    const { data } = await requestJson<Record<string, unknown>>(
      'beem',
      `${this.baseUrl}/v1/report?message_id=${encodeURIComponent(providerMessageId)}`,
      { method: 'GET', headers: this.headers() },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );
    return { status: String(data.status ?? 'unknown') };
  }

  async balance(): Promise<number> {
    const { data } = await requestJson<Record<string, unknown>>(
      'beem',
      `${this.baseUrl}/v1/balance`,
      { method: 'GET', headers: this.headers() },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );
    return Number(data.balance ?? 0);
  }
}
