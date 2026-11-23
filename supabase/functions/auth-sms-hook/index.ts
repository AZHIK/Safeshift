import { handle } from './handler.ts';

// Not wrapped in createHandler: Supabase Auth expects the hook's own response
// shape ({} on success, { error: { http_code, message } } on failure), not the
// shared { data, error } envelope.
Deno.serve((req) => handle(req));
