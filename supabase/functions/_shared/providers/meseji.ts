import { ProviderError } from '../errors.ts';
import type { SmsResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

/**
 * Meseji (https://meseji.co.tz) bulk SMS client. SafeShift's only SMS provider.
 *
 * API: `POST {baseUrl}/sms/send` with an `x-api-key` header and a JSON body of
 * `sender_id`, `message`, and `contacts` (comma-separated international
 * numbers without the leading +, e.g. `255712345678`).
 */
export interface MesejiConfig {
  apiKey: string;
  senderId: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export const MESEJI_DEFAULT_BASE_URL = 'https://meseji.co.tz/api/v1';

/** Converts `+255712345678`, `0712345678`, or `255712345678` to `255712345678`. */
export function mesejiContact(phone: string): string {
  let digits = phone.replace(/\D/g, '');
  if (digits.startsWith('0') && digits.length === 10) digits = `255${digits.slice(1)}`;
  if (digits.length === 9) digits = `255${digits}`;
  return digits;
}

function pickId(data: Record<string, unknown>): string | undefined {
  const nested = data.data && typeof data.data === 'object'
    ? (data.data as Record<string, unknown>)
    : {};
  for (const source of [data, nested]) {
    for (const key of ['batch_id', 'batchId', 'message_id', 'id', 'request_id']) {
      const value = source[key];
      if (typeof value === 'string' || typeof value === 'number') return String(value);
    }
  }
  return undefined;
}

export class MesejiClient {
  private readonly baseUrl: string;
  private readonly config: MesejiConfig;

  constructor(config: MesejiConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? MESEJI_DEFAULT_BASE_URL).replace(/\/$/, '');
  }

  private headers(): Record<string, string> {
    return {
      'x-api-key': this.config.apiKey,
      'content-type': 'application/json',
      accept: 'application/json',
    };
  }

  private options() {
    return {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
    };
  }

  async sendSms(to: string, from: string, body: string, reference: string): Promise<SmsResult> {
    const { data } = await requestJson<Record<string, unknown>>(
      'meseji',
      `${this.baseUrl}/sms/send`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          sender_id: from || this.config.senderId,
          message: body,
          contacts: mesejiContact(to),
        }),
      },
      this.options(),
    );

    // Some gateways answer 200 with a failure flag instead of an HTTP error.
    const payload = data ?? {};
    if (payload.success === false || payload.status === 'error' || payload.status === false) {
      throw new ProviderError('meseji', 'meseji rejected the request', {
        provider_message: typeof payload.message === 'string'
          ? payload.message.slice(0, 200)
          : undefined,
      });
    }

    return { provider_message_id: pickId(payload) ?? reference, status: 'sent' };
  }

  async checkDeliveryStatus(batchId: string): Promise<Record<string, unknown>> {
    const { data } = await requestJson<Record<string, unknown>>(
      'meseji',
      `${this.baseUrl}/sms/stats/${encodeURIComponent(batchId)}`,
      { method: 'GET', headers: this.headers() },
      this.options(),
    );
    return data ?? {};
  }

  async balance(): Promise<number> {
    const { data } = await requestJson<Record<string, unknown>>(
      'meseji',
      `${this.baseUrl}/sms/balance`,
      { method: 'GET', headers: this.headers() },
      this.options(),
    );
    const nested = data?.data && typeof data.data === 'object'
      ? (data.data as Record<string, unknown>)
      : {};
    return Number(data?.balance ?? nested.balance ?? 0);
  }
}
