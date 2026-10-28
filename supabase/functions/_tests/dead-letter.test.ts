import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { recordDeadLetter } from '../_shared/dead_letter.ts';
import { createSupabaseMock } from './mocks.ts';

Deno.test('exhausted provider calls are recorded in the dead letter queue', async () => {
  const captured: { value: Record<string, unknown> | null } = { value: null };
  const client = createSupabaseMock({
    tables: {
      dead_letter_queue: {
        insert: (context) => {
          captured.value = context.payload as Record<string, unknown>;
          return { data: null, error: null };
        },
      },
    },
  });

  await recordDeadLetter(
    'payment-selcom-initiate',
    { payment_id: 'payment-1', job_id: 'job-1' },
    new Error('provider unavailable'),
    4,
    client,
  );

  assertEquals(captured.value?.function_name, 'payment-selcom-initiate');
  assertEquals(captured.value?.attempt_count, 4);
  assertEquals(captured.value?.payload, { payment_id: 'payment-1', job_id: 'job-1' });
  assertEquals(captured.value?.error_message, 'provider unavailable');
});
