import type { ApiErrorBody } from './types/index.ts';

export class AppError extends Error {
  readonly code: string;
  readonly status: number;
  readonly details?: unknown;
  readonly expose: boolean;

  constructor(
    status: number,
    code: string,
    message: string,
    details?: unknown,
    expose = true,
  ) {
    super(message);
    this.name = new.target.name;
    this.status = status;
    this.code = code;
    this.details = details;
    this.expose = expose;
  }

  toBody(): ApiErrorBody {
    return {
      code: this.code,
      message: this.expose ? this.message : 'Internal server error',
      ...(this.details === undefined ? {} : { details: this.details }),
    };
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required', details?: unknown) {
    super(401, 'unauthorized', message, details);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions', details?: unknown) {
    super(403, 'forbidden', message, details);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found', details?: unknown) {
    super(404, 'not_found', message, details);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource conflict', details?: unknown) {
    super(409, 'conflict', message, details);
  }
}

export class ValidationError extends AppError {
  constructor(message = 'Invalid request', details?: unknown) {
    super(422, 'validation_error', message, details);
  }
}

export class ProviderError extends AppError {
  readonly provider: string;

  constructor(provider: string, message = 'Provider request failed', details?: unknown) {
    super(502, 'provider_error', message, details);
    this.provider = provider;
  }
}

export class ProviderUnavailableError extends AppError {
  readonly provider: string;

  constructor(provider: string, message = 'Provider unavailable', details?: unknown) {
    // The public contract uses 502 for all exhausted provider and upstream
    // failures. The code distinguishes transport failures from rejections.
    super(502, 'provider_unavailable', message, details);
    this.provider = provider;
  }
}

export class RateLimitError extends AppError {
  readonly retryAfter: number;

  constructor(retryAfter = 60, message = 'Rate limit exceeded', details?: unknown) {
    super(429, 'rate_limited', message, details);
    this.retryAfter = retryAfter;
  }
}

export class InternalError extends AppError {
  constructor(message = 'Internal server error', details?: unknown) {
    super(500, 'internal_error', message, details, false);
  }
}

/**
 * Convert database and unknown errors into a safe API error.
 * PostgREST SQLSTATE values are mapped to the Phase 7 HTTP contract.
 */
export function normalizeError(error: unknown): AppError {
  if (error instanceof AppError) return error;

  if (error instanceof Error) {
    const code = (error as Error & { code?: string }).code;
    switch (code) {
      case 'P0002':
        return new NotFoundError(error.message);
      case '42501':
        return new ForbiddenError(error.message);
      case '23505':
        return new ConflictError(error.message);
      case '22023':
      case '22004':
      case '23514':
        return new ValidationError(error.message);
      case '23503':
        return new ValidationError(error.message);
      default:
        return new InternalError('Internal server error', { type: error.name });
    }
  }

  return new InternalError('Internal server error');
}
