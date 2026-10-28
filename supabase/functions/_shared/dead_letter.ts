import { serviceClient, type SupabaseClient } from './db.ts';
import { redact, RequestLogger } from './logger.ts';

export async function recordDeadLetter(
  functionName: string,
  payload: Record<string, unknown>,
  error: unknown,
  attemptCount = 4,
  client: SupabaseClient = serviceClient(),
): Promise<void> {
  const err = error instanceof Error ? error : new Error(String(error));
  const sanitized = redact(err) as { message?: string; stack?: string };
  const { error: insertError } = await client.from('dead_letter_queue').insert({
    function_name: functionName,
    payload,
    error_message: (sanitized.message ?? 'unknown error').slice(0, 2_000),
    error_stack: sanitized.stack?.slice(0, 8_000) ?? null,
    attempt_count: attemptCount,
    last_attempt_at: new Date().toISOString(),
  });

  if (insertError) {
    // Never mask the original provider failure with a DLQ write failure.
    const logger = new RequestLogger(functionName, 'dead-letter');
    logger.error('dead_letter_insert_failed', insertError, { original_error: err.message });
  }
}
