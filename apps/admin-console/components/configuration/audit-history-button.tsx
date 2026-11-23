'use client';

import { useEffect, useRef, useState } from 'react';

import { RowMenu, type MenuItem } from '@/components/row-menu';
import { formatDate } from '@/lib/format';

export type AuditEntry = {
  entry_id: string;
  created_at: string;
  actor_id: string | null;
  actor_name: string;
  action: string;
  old_value: unknown;
  new_value: unknown;
  source: string;
};

export type AuditQuery = {
  limit?: number;
  from?: string;
  to?: string;
  actor?: string;
};

/** Formats a value for the audit table. */
export function formatAuditValue(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

/** Builds the CSV file for the visible audit entries. */
export function toCsv(entries: AuditEntry[]): string {
  const escape = (value: string) => `"${value.replace(/"/g, '""').replace(/\r?\n/g, ' ')}"`;

  const header = ['Timestamp', 'Actor', 'Action', 'Source', 'Old value', 'New value'];
  const lines = [header.map(escape).join(',')];

  for (const entry of entries) {
    lines.push(
      [
        entry.created_at,
        entry.actor_name,
        entry.action,
        entry.source,
        formatAuditValue(entry.old_value),
        formatAuditValue(entry.new_value),
      ]
        .map(escape)
        .join(','),
    );
  }

  return lines.join('\n');
}

function copy(text: string) {
  void navigator.clipboard?.writeText(text).catch(() => undefined);
}

/** The ⋮ menu for one audit entry. Entries are append-only, so these only read. */
export function auditEntryItems(entry: AuditEntry): MenuItem[] {
  const items: MenuItem[] = [];
  if (entry.actor_id) items.push({ kind: 'link', label: 'View actor', href: `/users/${entry.actor_id}` });
  items.push(
    { kind: 'link', label: 'Open audit log', href: '/audit' },
    { kind: 'button', label: 'Copy old value', onSelect: () => copy(formatAuditValue(entry.old_value)) },
    { kind: 'button', label: 'Copy new value', onSelect: () => copy(formatAuditValue(entry.new_value)) },
    { kind: 'button', label: 'Copy entry ID', onSelect: () => copy(entry.entry_id) },
    { kind: 'disabled', label: 'Edit or delete', note: 'Audit entries are permanent and cannot be changed.' },
  );
  return items;
}

/**
 * The audit history drawer.
 *
 * Shows the merged trail for one configuration row: the row-level trigger
 * trail and the console's own action log.
 */
export function AuditHistoryDrawer({
  open,
  recordLabel,
  onClose,
  load,
}: {
  open: boolean;
  recordLabel: string;
  onClose: () => void;
  load: (query: AuditQuery) => Promise<AuditEntry[]>;
}) {
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [actor, setActor] = useState('');
  const [truncated, setTruncated] = useState(false);

  // The loader is read through a ref so a new function identity on every
  // render does not restart the read on every render.
  const loadRef = useRef(load);

  useEffect(() => {
    loadRef.current = load;
  }, [load]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;

    void (async () => {
      try {
        const result = await loadRef.current({
          limit: 50,
          from: from || undefined,
          to: to || undefined,
          actor: actor || undefined,
        });
        if (cancelled) return;
        setEntries(result);
        setTruncated(result.length >= 50);
        setError(null);
      } catch (caught) {
        if (cancelled) return;
        setError(caught instanceof Error ? caught.message : 'The audit trail could not be read.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [actor, from, open, to]);

  if (!open) return null;

  const actors = [...new Set(entries.map((entry) => entry.actor_name).filter(Boolean))];

  const exportCsv = () => {
    const csv = toCsv(entries);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `audit-history-${recordLabel.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div
      aria-modal="true"
      className="drawer-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
      role="dialog"
    >
      <aside className="drawer">
        <div className="drawer-head">
          <div>
            <h2 className="dialog-title">Audit history</h2>
            <p className="small muted">{recordLabel}</p>
          </div>
          <button aria-label="Close" className="btn btn-sm" onClick={onClose} type="button">
            ✕
          </button>
        </div>

        <div className="drawer-filters">
          <div className="field">
            <label htmlFor="audit-from">From</label>
            <input
              className="input"
              id="audit-from"
              onChange={(event) => setFrom(event.target.value)}
              type="date"
              value={from}
            />
          </div>
          <div className="field">
            <label htmlFor="audit-to">To</label>
            <input
              className="input"
              id="audit-to"
              onChange={(event) => setTo(event.target.value)}
              type="date"
              value={to}
            />
          </div>
          <div className="field">
            <label htmlFor="audit-actor">Actor</label>
            <select
              className="input"
              id="audit-actor"
              onChange={(event) => setActor(event.target.value)}
              value={actor}
            >
              <option value="">Everyone</option>
              {actors.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </div>
          <div className="inline">
            <button
              className="btn btn-sm"
              disabled={entries.length === 0}
              onClick={exportCsv}
              type="button"
            >
              Export to CSV
            </button>
          </div>
        </div>

        <div className="drawer-body">
          {error ? <div className="notice notice-error">{error}</div> : null}
          {loading ? (
            <div className="skeleton" style={{ height: 120 }} />
          ) : entries.length === 0 ? (
            <p className="muted">No audit entries for this record yet.</p>
          ) : (
            <>
              <table className="audit-table">
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Actor</th>
                    <th>Action</th>
                    <th>Old value</th>
                    <th>New value</th>
                    <th className="col-actions">
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {entries.map((entry) => (
                    <tr key={entry.entry_id}>
                      <td className="nowrap small">{formatDate(entry.created_at)}</td>
                      <td className="small">{entry.actor_name}</td>
                      <td className="small">
                        {entry.action}
                        <div className="muted" style={{ fontSize: 11 }}>
                          {entry.source}
                        </div>
                      </td>
                      <td>
                        <pre className="audit-value">{formatAuditValue(entry.old_value)}</pre>
                      </td>
                      <td>
                        <pre className="audit-value">{formatAuditValue(entry.new_value)}</pre>
                      </td>
                      <td className="col-actions">
                        <RowMenu label={`Actions for ${entry.action}`} items={auditEntryItems(entry)} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {truncated ? (
                <p className="small muted" style={{ marginTop: 10 }}>
                  Showing the last 50 entries — view all of them in the audit viewer.
                </p>
              ) : null}
            </>
          )}
        </div>
      </aside>
    </div>
  );
}
