import { AppError, ProviderError, ProviderUnavailableError, RateLimitError } from './errors.ts';
import type { RetryOptions } from './types/index.ts';

const DEFAULT_DELAYS_MS = [1_000, 4_000, 16_000];

export function isRetryableError(error: unknown): boolean {
  if (error instanceof RateLimitError) return true;
  if (error instanceof ProviderUnavailableError) return true;
  if (error instanceof ProviderError) {
    const status = (error.details as { status?: number } | undefined)?.status;
    return status === undefined || status >= 500 || status === 408 || status === 429;
  }
  if (error instanceof AppError) {
    return error.status >= 500 || error.status === 429 || error.status === 408;
  }
  if (error instanceof Error) {
    if (error.name === 'AbortError' || error.name === 'TimeoutError') return true;
    if (error.name === 'TypeError') return true;
    const message = error.message.toLowerCase();
    return (
      message.includes('network') ||
      message.includes('fetch failed') ||
      message.includes('connection') ||
      message.includes('timed out')
    );
  }
  return false;
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const maxRetries = options.maxRetries ?? 3;
  const baseDelayMs = options.baseDelayMs ?? 1_000;
  const maxDelayMs = options.maxDelayMs ?? 16_000;
  const sleep = options.sleep ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  const delays = DEFAULT_DELAYS_MS.map((delay) =>
    Math.min(delay * (baseDelayMs / 1_000), maxDelayMs)
  );

  let lastError: unknown;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt >= maxRetries || !isRetryableError(error)) {
        throw error;
      }
      const delayMs = delays[Math.min(attempt, delays.length - 1)];
      options.onRetry?.(attempt + 1, error, delayMs);
      await sleep(delayMs);
    }
  }

  throw lastError;
}
