import { redirect } from 'next/navigation';

import { getCallerPermissions } from '@/lib/configuration/guard';
import { CONFIGURATION_GROUPS } from '@/lib/configuration/resources';

export const dynamic = 'force-dynamic';

/**
 * The entry point of the Configuration section.
 *
 * There is no overview page: the section is a set of tables, so the index
 * sends the operator straight to the first page they are allowed to open.
 */
export default async function ConfigurationIndexPage() {
  const caller = await getCallerPermissions();

  for (const group of CONFIGURATION_GROUPS) {
    for (const item of group.items) {
      if (!caller.permissions.has(item.permission)) continue;
      const child = item.children?.find((entry) => caller.permissions.has(entry.permission));
      redirect(child?.href ?? item.href);
    }
  }

  redirect(
    `/dashboard?error=${encodeURIComponent('Your account has no configuration permissions.')}`,
  );
}
