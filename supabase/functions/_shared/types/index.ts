/**
 * Shared Phase 7 Edge Function contracts.
 *
 * These types intentionally stay independent of generated database types so
 * the Edge Function bundle does not need a build step before local serving.
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface ApiErrorBody {
  code: string;
  message: string;
  details?: unknown;
}

export interface ApiEnvelope<T> {
  data: T | null;
  error: ApiErrorBody | null;
}

export interface AuthContext {
  userId: string;
  role: string;
  countryId: string | null;
  permissions: string[];
  token: string;
  claims: Record<string, unknown>;
}

export interface RequestContext {
  functionName: string;
  requestId: string;
  startedAt: number;
  ip: string;
  auth?: AuthContext;
}

export interface RetryOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  sleep?: (ms: number) => Promise<void>;
  onRetry?: (attempt: number, error: unknown, delayMs: number) => void;
}

export interface ProviderResult<T> {
  ok: boolean;
  data: T;
  status: number;
}

export interface PaymentInitiation {
  provider_reference: string;
  status: 'pending' | 'succeeded' | 'failed';
  redirect_url: string | null;
}

export interface PaymentVerification {
  status: 'pending' | 'succeeded' | 'failed';
  amount: number;
  paid_at: string | null;
}

export interface RefundResult {
  refund_reference: string;
  status: 'pending' | 'succeeded' | 'failed';
}

export interface SmsResult {
  provider_message_id: string;
  status: 'sent' | 'queued' | 'failed';
}

export interface EmailResult {
  provider_message_id: string;
  status: 'sent' | 'queued' | 'failed';
}

export interface PushResult {
  provider_message_id: string;
  status: 'sent' | 'failed';
}

export interface DistanceResult {
  distance_km: number;
  duration_min: number;
}

export interface GeocodeResult {
  lat: number;
  lng: number;
  formatted_address: string;
  place_id: string;
}

export interface AutocompletePrediction {
  description: string;
  place_id: string;
}
