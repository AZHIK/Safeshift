import { ProviderError, ProviderUnavailableError } from '../errors.ts';
import { structuredLog } from '../logger.ts';
import { withRetry } from '../retry.ts';

export type FetchLike = typeof fetch;
export type SleepLike = (ms: number) => Promise<void>;

export interface HttpClientOptions {
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
  timeoutMs?: number;
}

export interface ProviderResponse<T> {
  data: T;
  status: number;
}

function providerLog(
  provider: string,
  requestId: string | undefined,
  message: string,
  context: Record<string, unknown>,
): void {
  structuredLog('warn', `provider:${provider}`, requestId ?? 'provider-call', message, context);
}

/**
 * Extract the actionable part of a Google-style provider error envelope.
 *
 * Only the canonical `error.status` and `error.message` are kept. The full
 * body is never returned because it can echo request coordinates. Coordinate
 * shaped numbers are scrubbed from the message for the same reason.
 */
function extractProviderError(body: unknown): { status?: string; message?: string } {
  if (!body || typeof body !== 'object') return {};
  const envelope = (body as { error?: unknown }).error;
  if (!envelope || typeof envelope !== 'object') return {};

  const rawStatus = (envelope as { status?: unknown }).status;
  const rawMessage = (envelope as { message?: unknown }).message;
  const result: { status?: string; message?: string } = {};

  if (typeof rawStatus === 'string' && rawStatus.trim()) {
    result.status = rawStatus.trim();
  }
  if (typeof rawMessage === 'string' && rawMessage.trim()) {
    result.message = rawMessage
      .trim()
      .replace(/-?\d+\.\d{3,}/g, '[redacted]')
      .slice(0, 200);
  }
  return result;
}

/**
 * Perform a provider HTTP call with timeout, retry, and structured logging.
 * Response bodies are never logged because they can contain customer PII.
 */
export function requestJson<T>(
  provider: string,
  url: string,
  init: RequestInit,
  options: HttpClientOptions = {},
): Promise<ProviderResponse<T>> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const timeoutMs = options.timeoutMs ?? 30_000;

  return withRetry(
    async () => {
      const started = performance.now();
      let response: Response;
      try {
        response = await fetchImpl(url, {
          ...init,
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (error) {
        providerLog(provider, options.requestId, 'provider_network_error', {
          method: init.method ?? 'GET',
          url_path: new URL(url).pathname,
          duration_ms: Math.round(performance.now() - started),
          error_type: error instanceof Error ? error.name : 'unknown',
        });
        throw new ProviderUnavailableError(provider, `${provider} is unavailable`);
      }

      const durationMs = Math.round(performance.now() - started);
      const text = await response.text();
      let body: unknown = null;
      try {
        body = text ? JSON.parse(text) : null;
      } catch {
        body = { raw: text.slice(0, 500) };
      }

      providerLog(provider, options.requestId, 'provider_response', {
        method: init.method ?? 'GET',
        url_path: new URL(url).pathname,
        status: response.status,
        duration_ms: durationMs,
      });

      if (!response.ok) {
        // Provider error envelopes carry the actionable detail
        // (INVALID_ARGUMENT, PERMISSION_DENIED, API_KEY_INVALID, ...).
        // Without it a wrong endpoint path and a bad enum value look
        // identical from the outside.
        const providerError = extractProviderError(body);
        const details = {
          status: response.status,
          ...(providerError.status ? { provider_status: providerError.status } : {}),
          ...(providerError.message ? { provider_message: providerError.message } : {}),
        };
        if (response.status === 429) {
          throw new ProviderUnavailableError(provider, `${provider} rate limited`, details);
        }
        if (response.status >= 500) {
          throw new ProviderUnavailableError(provider, `${provider} returned ${response.status}`, details);
        }
        throw new ProviderError(provider, `${provider} rejected the request`, details);
      }

      return { data: body as T, status: response.status };
    },
    {
      sleep: options.sleep,
      onRetry: (attempt, error, delayMs) => {
        providerLog(provider, options.requestId, 'provider_retry', {
          attempt,
          delay_ms: delayMs,
          error_type: error instanceof Error ? error.name : 'unknown',
        });
      },
    },
  );
}

export async function hmacSha256Hex(rawBody: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
