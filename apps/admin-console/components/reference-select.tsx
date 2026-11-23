'use client';

import { useEffect, useRef, useState } from 'react';

import type { ReferenceChoices, ReferenceOption } from '@/lib/record-labels';

/**
 * A dropdown for a reference field, showing names instead of ids. Large
 * tables get a search box that loads matching choices from the server.
 */
export function ReferenceSelect({
  id,
  name,
  table,
  column,
  choices,
  defaultValue,
  required,
  blankLabel,
  search,
}: {
  id: string;
  name: string;
  table: string;
  column: string;
  choices: ReferenceChoices;
  defaultValue: string;
  required: boolean;
  blankLabel: string;
  search: (table: string, column: string, q: string) => Promise<ReferenceChoices>;
}) {
  const [value, setValue] = useState(defaultValue);
  const [options, setOptions] = useState<ReferenceOption[]>(choices.options);
  const [more, setMore] = useState(choices.more);
  // null until the user types, so the first page is not loaded twice.
  const [query, setQuery] = useState<string | null>(null);
  const [status, setStatus] = useState<'idle' | 'loading' | 'error'>('idle');
  // The chosen option stays available while the search changes the list.
  const selected = useRef<ReferenceOption | undefined>(choices.options.find((o) => o.value === defaultValue));
  const searchable = choices.more;

  useEffect(() => {
    if (!searchable || query === null) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      setStatus('loading');
      try {
        const next = await search(table, column, query);
        if (cancelled) return;
        const keep = selected.current;
        setOptions(keep && !next.options.some((o) => o.value === keep.value) ? [keep, ...next.options] : next.options);
        setMore(next.more);
        setStatus('idle');
      } catch {
        if (!cancelled) setStatus('error');
      }
    }, query ? 300 : 0);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [column, query, search, searchable, table]);

  return (
    <div className="reference-select">
      {searchable ? (
        <input
          className="input"
          type="search"
          aria-label="Search choices"
          placeholder="Type to search…"
          value={query ?? ''}
          onChange={(e) => setQuery(e.target.value)}
        />
      ) : null}
      <select
        className="input"
        id={id}
        name={name}
        value={value}
        required={required}
        onChange={(e) => {
          setValue(e.target.value);
          selected.current = options.find((o) => o.value === e.target.value);
        }}
      >
        <option value="">{blankLabel}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      {status === 'loading' ? <span className="small muted">Searching…</span> : null}
      {status === 'error' ? <span className="small muted">Could not search. Try again.</span> : null}
      {status === 'idle' && more ? (
        <span className="small muted">Showing the first {options.length}. Type to find others.</span>
      ) : null}
    </div>
  );
}
