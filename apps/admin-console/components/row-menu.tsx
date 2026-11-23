'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

export type MenuItem =
  | { kind: 'link'; label: string; href: string }
  | {
      kind: 'form';
      label: string;
      action: (formData: FormData) => void | Promise<void>;
      fields?: Record<string, string>;
      /** Ask before submitting. */
      confirm?: string;
      /** Ask for a reason (sent as "reason"). */
      reason?: string;
      danger?: boolean;
    }
  | { kind: 'disabled'; label: string; note: string }
  /** Client-only: runs a callback (for menus rendered inside client components). */
  | { kind: 'button'; label: string; onSelect: () => void; danger?: boolean };

/** The ⋮ button at the end of a table row, opening that row's actions. */
export function RowMenu({ items, label = 'Actions' }: { items: MenuItem[]; label?: string }) {
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState<Extract<MenuItem, { kind: 'form' }> | null>(null);
  const [position, setPosition] = useState({ top: 0, right: 0 });
  const button = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    const close = (event: Event) => {
      const target = event.target as Node | null;
      if (target && (menu.current?.contains(target) || button.current?.contains(target))) return;
      setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
        button.current?.focus();
      }
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', onKey);
    window.addEventListener('scroll', close, true);
    window.addEventListener('resize', close);
    menu.current?.querySelector<HTMLElement>('[role="menuitem"]:not([aria-disabled="true"])')?.focus();
    return () => {
      document.removeEventListener('mousedown', close);
      document.removeEventListener('keydown', onKey);
      window.removeEventListener('scroll', close, true);
      window.removeEventListener('resize', close);
    };
  }, [open]);

  function toggle() {
    const rect = button.current?.getBoundingClientRect();
    if (rect) setPosition({ top: rect.bottom + 4, right: Math.max(8, window.innerWidth - rect.right) });
    setOpen((o) => !o);
  }

  function onMenuKey(event: React.KeyboardEvent) {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
    event.preventDefault();
    const all = Array.from(menu.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
    const i = all.indexOf(document.activeElement as HTMLElement);
    all[(i + (event.key === 'ArrowDown' ? 1 : all.length - 1)) % all.length]?.focus();
  }

  return (
    <>
      <button
        ref={button}
        type="button"
        className="row-menu-button"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={toggle}
      >
        <span aria-hidden="true">⋮</span>
      </button>
      {open && typeof document !== 'undefined'
        ? createPortal(
            <div
              ref={menu}
              id={menuId}
              role="menu"
              aria-label={label}
              className="row-menu"
              style={{ top: position.top, right: position.right }}
              onKeyDown={onMenuKey}
            >
              {items.length === 0 ? <div className="row-menu-note">No actions available</div> : null}
              {items.map((item) => {
                if (item.kind === 'link') {
                  return (
                    <a key={item.label} role="menuitem" className="row-menu-item" href={item.href}>
                      {item.label}
                    </a>
                  );
                }
                if (item.kind === 'button') {
                  return (
                    <button
                      key={item.label}
                      type="button"
                      role="menuitem"
                      className={`row-menu-item${item.danger ? ' row-menu-danger' : ''}`}
                      onClick={() => {
                        setOpen(false);
                        item.onSelect();
                      }}
                    >
                      {item.label}
                    </button>
                  );
                }
                if (item.kind === 'disabled') {
                  return (
                    <div key={item.label} role="menuitem" aria-disabled="true" tabIndex={-1} className="row-menu-item" title={item.note}>
                      {item.label}
                      <div className="row-menu-note">{item.note}</div>
                    </div>
                  );
                }
                if (item.confirm || item.reason) {
                  return (
                    <button
                      key={item.label}
                      type="button"
                      role="menuitem"
                      className={`row-menu-item${item.danger ? ' row-menu-danger' : ''}`}
                      onClick={() => {
                        setOpen(false);
                        setPending(item);
                      }}
                    >
                      {item.label}…
                    </button>
                  );
                }
                return (
                  <form key={item.label} action={item.action}>
                    {Object.entries(item.fields ?? {}).map(([name, value]) => (
                      <input key={name} type="hidden" name={name} value={value} />
                    ))}
                    <button type="submit" role="menuitem" className={`row-menu-item${item.danger ? ' row-menu-danger' : ''}`}>
                      {item.label}
                    </button>
                  </form>
                );
              })}
            </div>,
            document.body,
          )
        : null}
      {pending && typeof document !== 'undefined'
        ? createPortal(
            <div className="row-dialog-backdrop" onMouseDown={(e) => e.target === e.currentTarget && setPending(null)}>
              <div role="dialog" aria-modal="true" aria-labelledby={`${menuId}-title`} className="row-dialog card card-pad">
                <h2 className="card-title" id={`${menuId}-title`}>
                  {pending.label}
                </h2>
                {pending.confirm ? <p className="card-sub">{pending.confirm}</p> : null}
                <form action={pending.action} className="form" style={{ marginTop: 12 }}>
                  {Object.entries(pending.fields ?? {}).map(([name, value]) => (
                    <input key={name} type="hidden" name={name} value={value} />
                  ))}
                  {pending.reason ? (
                    <label className="field">
                      {pending.reason}
                      <textarea className="input" name="reason" rows={3} required minLength={3} maxLength={500} autoFocus />
                    </label>
                  ) : null}
                  <div className="inline" style={{ gap: 8, justifyContent: 'flex-end' }}>
                    <button type="button" className="btn" onClick={() => setPending(null)}>
                      Cancel
                    </button>
                    <button type="submit" className={`btn ${pending.danger ? 'btn-danger' : 'btn-primary'}`} autoFocus={!pending.reason}>
                      {pending.label}
                    </button>
                  </div>
                </form>
              </div>
            </div>,
            document.body,
          )
        : null}
    </>
  );
}
