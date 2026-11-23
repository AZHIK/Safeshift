import Link from 'next/link';
import type { ReactNode } from 'react';

import { signOutAction } from '@/app/actions/auth';
import { canSee } from '@/lib/areas';
import type { AdminSession } from '@/lib/auth';
import { CONFIGURATION_GROUPS, CONFIGURATION_PERMISSIONS } from '@/lib/configuration/resources';

const groups: {
  label: string;
  items: { href: string; label: string; area: string; glyph: string }[];
}[] = [
  {
    label: 'Overview',
    items: [
      { href: '/dashboard', label: 'Dashboard', area: 'dashboard', glyph: '◈' },
      { href: '/analytics', label: 'Analytics', area: 'analytics', glyph: '▥' },
    ],
  },
  {
    label: 'Marketplace',
    items: [
      { href: '/jobs', label: 'Jobs', area: 'jobs', glyph: '⇄' },
      { href: '/users', label: 'Users', area: 'users', glyph: '◎' },
      { href: '/drivers', label: 'Drivers', area: 'drivers', glyph: '⛟' },
      { href: '/fleets', label: 'Fleets', area: 'fleets', glyph: '▤' },
      { href: '/catalog', label: 'Catalogue', area: 'catalog', glyph: '⬡' },
    ],
  },
  {
    label: 'Trust & Safety',
    items: [
      { href: '/verifications', label: 'Verification queue', area: 'verifications', glyph: '✓' },
      { href: '/incidents', label: 'Incidents & SOS', area: 'incidents', glyph: '!' },
      { href: '/disputes', label: 'Disputes', area: 'disputes', glyph: '⚖' },
      { href: '/support', label: 'Support', area: 'support', glyph: '☎' },
    ],
  },
  {
    label: 'Finance & Growth',
    items: [
      { href: '/payments', label: 'Payments', area: 'payments', glyph: '₵' },
      { href: '/payouts', label: 'Payouts', area: 'payouts', glyph: '↗' },
      { href: '/pricing', label: 'Pricing & tariffs', area: 'pricing', glyph: '≡' },
      { href: '/promos', label: 'Promos', area: 'promos', glyph: '%' },
    ],
  },
  {
    label: 'Governance',
    items: [
      { href: '/data-requests', label: 'Data requests', area: 'data-requests', glyph: '⌘' },
      { href: '/records/consent', label: 'Consent ledger', area: 'consent', glyph: '▤' },
      { href: '/governance', label: 'Regulatory reporting', area: 'governance', glyph: '▤' },
      { href: '/announcements', label: 'Announcements', area: 'announcements', glyph: '◉' },
      { href: '/audit', label: 'Audit log', area: 'audit', glyph: '▦' },
      { href: '/settings', label: 'Settings', area: 'settings', glyph: '⚙' },
    ],
  },
];

/**
 * The Configuration section of the sidebar.
 *
 * It only appears for an administrator who holds at least one configuration
 * permission, and only the pages that administrator may open are listed.
 */
function configurationItems(permissions: Set<string>) {
  const items: { href: string; label: string; glyph: string }[] = [];

  for (const group of CONFIGURATION_GROUPS) {
    for (const item of group.items) {
      if (!permissions.has(item.permission)) continue;

      if (item.children && item.children.length > 0) {
        const children = item.children.filter((child) => permissions.has(child.permission));
        if (children.length === 0) continue;
        for (const child of children) {
          items.push({ href: child.href, label: child.label, glyph: '·' });
        }
        continue;
      }

      items.push({ href: item.href, label: item.label, glyph: '⬢' });
    }
  }

  return items;
}

export function Shell({
  session,
  permissions,
  children,
}: {
  session: AdminSession;
  permissions: string[];
  children: ReactNode;
}) {
  const held = new Set(permissions);
  const configItems = configurationItems(held);
  const showsConfiguration =
    held.has('manage_configuration') ||
    CONFIGURATION_PERMISSIONS.some((permission) => held.has(permission));

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">S</div>
          <div>
            <div className="brand-name">SafeShift</div>
            <div className="brand-sub">Operations console</div>
          </div>
        </div>
        <nav>
          {groups.map((group) => {
            const items = group.items.filter((item) => canSee(held, item.area, session.role));
            if (items.length === 0) return null;
            return (
              <div className="nav-group" key={group.label}>
                <div className="nav-label">{group.label}</div>
                {items.map((item) => (
                  <Link className="nav-link" href={item.href} key={item.href}>
                    <span aria-hidden>{item.glyph}</span>
                    {item.label}
                  </Link>
                ))}
              </div>
            );
          })}

          {showsConfiguration && configItems.length > 0 ? (
            <div className="nav-group">
              <div className="nav-label">Configuration</div>
              {configItems.map((item) => (
                <Link className="nav-link nav-link-config" href={item.href} key={item.href}>
                  <span aria-hidden>{item.glyph}</span>
                  {item.label}
                </Link>
              ))}
            </div>
          ) : null}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div>{session.name}</div>
            <div>{session.email}</div>
          </div>
          <span className="sidebar-role">{session.role.replaceAll('_', ' ')}</span>
          <form action={signOutAction} style={{ marginTop: 10 }}>
            <button className="signout" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
