import { AppError, RateLimitError } from './errors.ts';
import type { ApiEnvelope } from './types/index.ts';

export const CORS_HEADERS: Record<string, string> = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, apikey, content-type, x-idempotency-key, x-request-id, x-cron-secret, x-internal-secret, x-selcom-signature, x-flutterwave-signature, x-signature, x-webhook-signature, verif-hash',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-max-age': '86400',
};

export function jsonResponse<T>(
  status: number,
  body: ApiEnvelope<T>,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...CORS_HEADERS,
      ...extraHeaders,
    },
  });
}

export function success<T>(data: T, status = 200): Response {
  return jsonResponse(status, { data, error: null });
}

export function created<T>(data: T): Response {
  return success(data, 201);
}

export function failure(error: AppError): Response {
  const headers: Record<string, string> = {};
  if (error instanceof RateLimitError) {
    headers['retry-after'] = String(error.retryAfter);
  }
  return jsonResponse(error.status, { data: null, error: error.toBody() }, headers);
}

export function optionsResponse(): Response {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}
