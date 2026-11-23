import { redirect } from 'next/navigation';
import { Suspense } from 'react';

import { FlashToast } from '@/components/flash-toast';
import { Shell } from '@/components/shell';
import { getAdminSession } from '@/lib/auth';
import { getCallerPermissions } from '@/lib/configuration/guard';

export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const session = await getAdminSession();
  if (!session) {
    redirect('/login?error=Your account has no active admin or fleet-owner role.');
  }

  const caller = await getCallerPermissions();

  return (
    <Shell permissions={[...caller.permissions]} session={session}>
      {children}
      <Suspense fallback={null}>
        <FlashToast />
      </Suspense>
    </Shell>
  );
}
