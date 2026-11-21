import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { normalizeError } from '../_shared/errors.ts';

Deno.test('PostgREST error objects keep their validation status and message', () => {
  // supabase-js returns these as plain objects, not Error instances.
  const error = normalizeError({
    code: '22023',
    details: null,
    hint: null,
    message: 'destination point is outside every active service city',
  });
  assertEquals(error.status, 422);
  assertEquals(error.message, 'destination point is outside every active service city');
});

Deno.test('PostgREST not-found and permission codes map to 404 and 403', () => {
  assertEquals(normalizeError({ code: 'P0002', message: 'missing' }).status, 404);
  assertEquals(normalizeError({ code: '42501', message: 'no' }).status, 403);
});

Deno.test('unknown database errors stay a generic 500 without the message', () => {
  const error = normalizeError({ code: 'XX000', message: 'secret internals' });
  assertEquals(error.status, 500);
  assertEquals(error.message, 'Internal server error');
});

Deno.test('non-error values are a generic 500', () => {
  assertEquals(normalizeError('boom').status, 500);
  assertEquals(normalizeError(null).status, 500);
});
