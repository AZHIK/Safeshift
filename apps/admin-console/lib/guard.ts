import { redirect } from 'next/navigation';

import { getAdminSession, type AdminSession } from './auth';

import { canSee } from './areas';
import { getCallerPermissions } from './configuration/guard';

export async function requireArea(area: string): Promise<AdminSession> {
  const session = await getAdminSession();
  if (!session) redirect('/login?error=Sign in with an admin account.');
  if (!canSee((await getCallerPermissions()).permissions, area, session.role)) redirect('/dashboard');
  return session;
}
