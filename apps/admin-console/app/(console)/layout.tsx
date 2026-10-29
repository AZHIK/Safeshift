import { redirect } from 'next/navigation';

import { Shell } from '@/components/shell';
import { getAdminSession } from '@/lib/auth';

export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const session = await getAdminSession();
  if (!session) {
    redirect('/login?error=Your account has no active admin or fleet-owner role.');
  }
  return <Shell session={session}>{children}</Shell>;
}
