'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { useState } from 'react';

import type { ConfigNavGroup } from '@/lib/configuration/resources';

/**
 * The Configuration sub-navigation.
 *
 * The groups are filtered by permission on the server, so an administrator
 * only ever sees the pages they can open.
 */
export function ConfigurationNav({ groups }: { groups: ConfigNavGroup[] }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  const isActive = (href: string) => pathname === href || pathname?.startsWith(`${href}/`);

  return (
    <nav className="config-subnav" aria-label="Configuration sections">
      {groups.map((group) => (
        <div className="config-subnav-group" key={group.label}>
          <div className="config-subnav-label">{group.label}</div>
          {group.items.map((item) => {
            const hasChildren = Boolean(item.children && item.children.length > 0);
            const open = !collapsed[item.slug];

            return (
              <div key={item.slug}>
                <div className="config-subnav-row">
                  <Link
                    className={`config-subnav-link${isActive(item.href) ? ' active' : ''}`}
                    href={item.href}
                  >
                    {item.label}
                  </Link>
                  {hasChildren ? (
                    <button
                      aria-expanded={open}
                      aria-label={`${open ? 'Collapse' : 'Expand'} ${item.label}`}
                      className="config-subnav-toggle"
                      onClick={() =>
                        setCollapsed((current) => ({ ...current, [item.slug]: !open }))
                      }
                      type="button"
                    >
                      {open ? '−' : '+'}
                    </button>
                  ) : null}
                </div>
                {hasChildren && open ? (
                  <div className="config-subnav-children">
                    {item.children?.map((child) => (
                      <Link
                        className={`config-subnav-child${isActive(child.href) ? ' active' : ''}`}
                        href={child.href}
                        key={child.slug}
                      >
                        {child.label}
                      </Link>
                    ))}
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      ))}
    </nav>
  );
}
