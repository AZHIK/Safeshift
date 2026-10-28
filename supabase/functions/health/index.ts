import { createHandler } from '../_shared/handler.ts';
import { handle } from './handler.ts';

Deno.serve(createHandler('health', handle));
