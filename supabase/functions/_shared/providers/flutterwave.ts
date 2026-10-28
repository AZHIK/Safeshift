import { ProviderError } from '../errors.ts';
import type { PaymentInitiation, PaymentVerification, RefundResult } from '../types/index.ts';
import {
  constantTimeEqual,
  type FetchLike,
  hmacSha256Hex,
  requestJson,
  type SleepLike,
} from './base.ts';

export interface FlutterwaveConfig {
  secretKey: string;
  secretHash?: string;
  baseUrl?: string;
  redirectUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export class FlutterwaveClient {
  private readonly baseUrl: string;
  private readonly config: FlutterwaveConfig;

  constructor(config: FlutterwaveConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://api.flutterwave.com/v3').replace(/\/$/, '');
  }

  private headers(): Record<string, string> {
    return {
      authorization: `Bearer ${this.config.secretKey}`,
      'content-type': 'application/json',
      accept: 'application/json',
    };
  }

  async initiatePayment(
    amount: number,
    currency: string,
    phoneOrCardToken: string,
    reference: string,
    description: string,
  ): Promise<PaymentInitiation> {
    const isCardToken = phoneOrCardToken.startsWith('card:');
    const { data } = await requestJson<Record<string, unknown>>(
      'flutterwave',
      `${this.baseUrl}/payments`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          tx_ref: reference,
          amount,
          currency,
          redirect_url: this.config.redirectUrl ?? 'https://safeshift.app/payment/callback',
          narration: description,
          ...(isCardToken
            ? { token: phoneOrCardToken.slice(5) }
            : { customer: { phonenumber: phoneOrCardToken } }),
        }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const payload = (data.data ?? data) as Record<string, unknown>;
    return {
      provider_reference: String(payload.id ?? payload.tx_ref ?? reference),
      status: 'pending',
      redirect_url: (payload.link ?? payload.redirect_url ?? null) as string | null,
    };
  }

  async verifyPayment(providerReference: string): Promise<PaymentVerification> {
    const { data } = await requestJson<Record<string, unknown>>(
      'flutterwave',
      `${this.baseUrl}/transactions/${encodeURIComponent(providerReference)}/verify`,
      { method: 'GET', headers: this.headers() },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const payload = (data.data ?? data) as Record<string, unknown>;
    const rawStatus = String(payload.status ?? 'pending').toLowerCase();
    return {
      status: rawStatus === 'successful' || rawStatus === 'succeeded'
        ? 'succeeded'
        : rawStatus === 'failed'
        ? 'failed'
        : 'pending',
      amount: Number(payload.amount ?? 0),
      paid_at: (payload.created_at ?? null) as string | null,
    };
  }

  async refundPayment(
    providerReference: string,
    amount: number,
    reason: string,
  ): Promise<RefundResult> {
    const { data } = await requestJson<Record<string, unknown>>(
      'flutterwave',
      `${this.baseUrl}/transactions/${encodeURIComponent(providerReference)}/refund`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ amount, comments: reason }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const payload = (data.data ?? data) as Record<string, unknown>;
    return {
      refund_reference: String(payload.id ?? payload.refund_reference ?? providerReference),
      status: String(payload.status ?? 'pending').toLowerCase() === 'completed'
        ? 'succeeded'
        : 'pending',
    };
  }

  async initiateTransfer(
    amount: number,
    currency: string,
    phone: string,
    reference: string,
    narration: string,
  ): Promise<{ provider_reference: string; status: 'pending' | 'succeeded' | 'failed' }> {
    const { data } = await requestJson<Record<string, unknown>>(
      'flutterwave',
      `${this.baseUrl}/transfers`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({
          account_bank: 'MPS',
          account_number: phone,
          amount,
          currency,
          narration,
          reference,
        }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const payload = (data.data ?? data) as Record<string, unknown>;
    const rawStatus = String(payload.status ?? 'pending').toLowerCase();
    return {
      provider_reference: String(payload.id ?? payload.reference ?? reference),
      status: rawStatus === 'successful' || rawStatus === 'succeeded'
        ? 'succeeded'
        : rawStatus === 'failed'
        ? 'failed'
        : 'pending',
    };
  }

  async verifyWebhookSignature(headers: Headers, rawBody: string): Promise<boolean> {
    if (!this.config.secretHash) return false;
    const provided = headers.get('verif-hash') ?? headers.get('x-flutterwave-signature');
    if (!provided) return false;
    if (headers.get('verif-hash')) return constantTimeEqual(provided, this.config.secretHash);
    const expected = await hmacSha256Hex(rawBody, this.config.secretHash);
    return constantTimeEqual(provided.toLowerCase(), expected.toLowerCase());
  }
}

export function assertFlutterwaveConfigured(secretKey?: string): void {
  if (!secretKey) {
    throw new ProviderError('flutterwave', 'Flutterwave credentials are not configured');
  }
}
