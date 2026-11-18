import { ConfigurationNav } from '@/components/configuration/configuration-nav';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { CONFIGURATION_GROUPS } from '@/lib/configuration/resources';

export const dynamic = 'force-dynamic';

/**
 * The shell of the Configuration section.
 *
 * The sub-navigation is filtered by permission on the server, so an
 * administrator only ever sees the pages they are allowed to open.
 */
export default async function ConfigurationLayout({ children }: { children: React.ReactNode }) {
  const caller = await getCallerPermissions();

  const groups = CONFIGURATION_GROUPS.map((group) => ({
    ...group,
    items: group.items
      .filter((item) => caller.permissions.has(item.permission))
      .map((item) =>
        item.children
          ? {
              ...item,
              children: item.children.filter((child) => caller.permissions.has(child.permission)),
            }
          : item,
      )
      .filter((item) => !item.children || item.children.length > 0),
  })).filter((group) => group.items.length > 0);

  return (
    <div className="config-layout">
      <ConfigurationNav groups={groups} />
      <div className="config-content">{children}</div>
    </div>
  );
}
