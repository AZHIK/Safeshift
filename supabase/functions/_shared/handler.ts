import { normalizeError } from './errors.ts';
import { RequestLogger } from './logger.ts';
import { failure, optionsResponse } from './response.ts';
import { getClientIp } from './auth.ts';
import type { RequestContext } from './types/index.ts';

export type FunctionHandler = (req: Request, ctx: RequestContext) => Promise<Response>;

/**
 * Wrap a function with request IDs, structured logs, CORS, and the standard
 * { data, error } response envelope.
 */
export function createHandler(functionName: string, handler: FunctionHandler) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return optionsResponse();

    const requestId = req.headers.get('x-request-id')?.trim() || crypto.randomUUID();
    const startedAt = performance.now();
    const logger = new RequestLogger(functionName, requestId, startedAt);
    const ctx: RequestContext = {
      functionName,
      requestId,
      startedAt,
      ip: getClientIp(req),
    };

    try {
      const response = await handler(req, ctx);
      logger.info('request_completed', {
        status: response.status,
        duration_ms: Math.round(performance.now() - startedAt),
      });
      return response;
    } catch (error) {
      const appError = normalizeError(error);
      logger.error('request_failed', error, {
        status: appError.status,
        code: appError.code,
        duration_ms: Math.round(performance.now() - startedAt),
      });
      return failure(appError);
    }
  };
}
