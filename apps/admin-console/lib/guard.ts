import { redirect } from 'next/navigation';

import { canSee, getAdminSession, type AdminSession } from './auth';

export async function requireArea(area: string): Promise<AdminSession> {
  const session = await getAdminSession();
  if (!session) redirect('/login?error=Sign in with an admin account.');
  if (!canSee(session.role, area)) redirect('/dashboard');
  return session;
}
