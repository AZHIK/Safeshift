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
        if (response.status === 429) {
          throw new ProviderUnavailableError(provider, `${provider} rate limited`, {
            status: response.status,
          });
        }
        if (response.status >= 500) {
          throw new ProviderUnavailableError(provider, `${provider} returned ${response.status}`, {
            status: response.status,
          });
        }
        throw new ProviderError(provider, `${provider} rejected the request`, {
          status: response.status,
        });
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
