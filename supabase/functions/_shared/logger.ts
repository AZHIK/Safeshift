import type { LogLevel } from './types/index.ts';

const REDACTED = '[redacted]';
const PII_KEY_PATTERN =
  /(phone|email|full_?name|display_?name|recipient|address|latitude|longitude|lat|lng|location|token|secret|authorization|password|card|pan|cvv)/i;
const PHONE_PATTERN = /\+?\d[\d\s().-]{7,}\d/g;
const EMAIL_PATTERN = /[^\s@]+@[^\s@]+\.[^\s@]+/g;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ISO_TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?)?$/;

function redactString(value: string): string {
  // IDs and timestamps are not PII. The phone matcher would otherwise treat
  // UUID digits and ISO dates as phone-number-shaped values.
  if (UUID_PATTERN.test(value) || ISO_TIMESTAMP_PATTERN.test(value)) return value;
  return value.replace(PHONE_PATTERN, REDACTED).replace(EMAIL_PATTERN, REDACTED);
}

/**
 * Recursively remove PII-shaped values. Logs are allowed to carry IDs,
 * provider names, status codes, durations, and sanitized error messages only.
 */
export function redact(value: unknown, depth = 0): unknown {
  if (depth > 6) return '[depth-limit]';
  if (value === null || value === undefined) return value;
  if (typeof value === 'string') return redactString(value);
  if (typeof value === 'number' || typeof value === 'boolean') return value;
  if (Array.isArray(value)) return value.map((item) => redact(item, depth + 1));
  if (value instanceof Error) {
    return {
      name: value.name,
      message: redactString(value.message),
      stack: value.stack ? redactString(value.stack) : undefined,
    };
  }
  if (typeof value === 'object') {
    const output: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      output[key] = PII_KEY_PATTERN.test(key) ? REDACTED : redact(item, depth + 1);
    }
    return output;
  }
  return String(value);
}

export function structuredLog(
  level: LogLevel,
  functionName: string,
  requestId: string,
  message: string,
  context: Record<string, unknown> = {},
): void {
  const record = {
    level,
    function_name: functionName,
    request_id: requestId,
    message: redactString(message),
    ...(redact(context) as Record<string, unknown>),
    timestamp: new Date().toISOString(),
  };

  const line = JSON.stringify(record);
  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.log(line);
  }
}

export class RequestLogger {
  constructor(
    private readonly functionName: string,
    private readonly requestId: string,
    private readonly startedAt = performance.now(),
  ) {}

  debug(message: string, context: Record<string, unknown> = {}): void {
    structuredLog('debug', this.functionName, this.requestId, message, context);
  }

  info(message: string, context: Record<string, unknown> = {}): void {
    structuredLog('info', this.functionName, this.requestId, message, {
      duration_ms: Math.round(performance.now() - this.startedAt),
      ...context,
    });
  }

  warn(message: string, context: Record<string, unknown> = {}): void {
    structuredLog('warn', this.functionName, this.requestId, message, {
      duration_ms: Math.round(performance.now() - this.startedAt),
      ...context,
    });
  }

  error(message: string, error: unknown, context: Record<string, unknown> = {}): void {
    structuredLog('error', this.functionName, this.requestId, message, {
      duration_ms: Math.round(performance.now() - this.startedAt),
      error: redact(error),
      ...context,
    });
  }
}
