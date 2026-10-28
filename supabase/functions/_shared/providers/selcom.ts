import { ProviderError } from '../errors.ts';
import type { PaymentInitiation, PaymentVerification, RefundResult } from '../types/index.ts';
import {
  constantTimeEqual,
  type FetchLike,
  hmacSha256Hex,
  requestJson,
  type SleepLike,
} from './base.ts';

export interface SelcomConfig {
  apiKey: string;
  apiSecret: string;
  vendorId?: string;
  webhookSecret?: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

export class SelcomClient {
  private readonly baseUrl: string;
  private readonly config: SelcomConfig;

  constructor(config: SelcomConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://api.selcom.co.tz').replace(/\/$/, '');
  }

  private headers(): Record<string, string> {
    return {
      authorization: `Bearer ${this.config.apiKey}`,
      'content-type': 'application/json',
      accept: 'application/json',
      'x-api-secret': this.config.apiSecret,
      ...(this.config.vendorId ? { 'x-vendor-id': this.config.vendorId } : {}),
    };
  }

  async initiatePayment(
    amount: number,
    currency: string,
    phone: string,
    reference: string,
    description: string,
  ): Promise<PaymentInitiation> {
    const { data } = await requestJson<Record<string, unknown>>(
      'selcom',
      `${this.baseUrl}/v1/checkout/create-order`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ amount, currency, phone, reference, description }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const providerReference = String(
      data.reference ?? data.order_id ?? data.transaction_id ?? reference,
    );
    const redirectUrl = (data.redirect_url ?? data.payment_url ?? data.checkout_url ?? null) as
      | string
      | null;

    return {
      provider_reference: providerReference,
      status: 'pending',
      redirect_url: redirectUrl,
    };
  }

  async verifyPayment(providerReference: string): Promise<PaymentVerification> {
    const { data } = await requestJson<Record<string, unknown>>(
      'selcom',
      `${this.baseUrl}/v1/checkout/order-status?order_id=${encodeURIComponent(providerReference)}`,
      { method: 'GET', headers: this.headers() },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const rawStatus = String(data.status ?? data.payment_status ?? 'pending').toLowerCase();
    const status = rawStatus === 'success' || rawStatus === 'succeeded' || rawStatus === 'paid'
      ? 'succeeded'
      : rawStatus === 'failed' || rawStatus === 'cancelled'
      ? 'failed'
      : 'pending';

    return {
      status,
      amount: Number(data.amount ?? 0),
      paid_at: (data.paid_at ?? data.completed_at ?? null) as string | null,
    };
  }

  async refundPayment(
    providerReference: string,
    amount: number,
    reason: string,
  ): Promise<RefundResult> {
    const { data } = await requestJson<Record<string, unknown>>(
      'selcom',
      `${this.baseUrl}/v1/refund`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ order_id: providerReference, amount, reason }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const refundReference = String(data.refund_reference ?? data.reference ?? providerReference);
    const rawStatus = String(data.status ?? 'pending').toLowerCase();
    return {
      refund_reference: refundReference,
      status: rawStatus === 'success' || rawStatus === 'succeeded' ? 'succeeded' : 'pending',
    };
  }

  async initiatePayout(
    amount: number,
    currency: string,
    phone: string,
    reference: string,
    description: string,
  ): Promise<{ provider_reference: string; status: 'pending' | 'succeeded' | 'failed' }> {
    const { data } = await requestJson<Record<string, unknown>>(
      'selcom',
      `${this.baseUrl}/v1/payout`,
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify({ amount, currency, phone, reference, description }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    const rawStatus = String(data.status ?? 'pending').toLowerCase();
    return {
      provider_reference: String(data.payout_reference ?? data.reference ?? reference),
      status: rawStatus === 'success' || rawStatus === 'succeeded'
        ? 'succeeded'
        : rawStatus === 'failed'
        ? 'failed'
        : 'pending',
    };
  }

  async verifyWebhookSignature(headers: Headers, rawBody: string): Promise<boolean> {
    if (!this.config.webhookSecret) return false;
    const provided = headers.get('x-selcom-signature') ??
      headers.get('x-signature') ??
      headers.get('x-webhook-signature');
    if (!provided) return false;
    const expected = await hmacSha256Hex(rawBody, this.config.webhookSecret);
    return constantTimeEqual(provided.toLowerCase(), expected.toLowerCase());
  }
}

export function assertSelcomConfigured(apiKey?: string, apiSecret?: string): void {
  if (!apiKey || !apiSecret) {
    throw new ProviderError('selcom', 'Selcom credentials are not configured');
  }
}
