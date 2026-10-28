import { type AuthDeps, defaultAuthDeps, requireUser } from '../_shared/auth.ts';
import { AppError } from '../_shared/errors.ts';
import { type SupabaseClient, userClient } from '../_shared/db.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface AuthValidateDeps {
  auth?: AuthDeps;
  userClient?: (jwt: string) => SupabaseClient;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: AuthValidateDeps = {},
): Promise<Response> {
  if (req.method !== 'GET') {
    throw new AppError(405, 'method_not_allowed', 'Use GET');
  }

  const authDeps = deps.auth ?? defaultAuthDeps();
  const auth = await requireUser(req, [], authDeps);
  const client = deps.userClient ? deps.userClient(auth.token) : userClient(auth.token);

  let permissions: string[] = [];
  const { data, error } = await client.rpc('current_permissions');
  if (error) throw error;
  if (Array.isArray(data)) permissions = data as string[];

  return success({
    userId: auth.userId,
    role: auth.role,
    countryId: auth.countryId,
    permissions,
    isActive: true,
  });
}
