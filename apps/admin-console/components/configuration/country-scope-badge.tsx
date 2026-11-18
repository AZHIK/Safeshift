import type { ReactNode } from 'react';

/**
 * The country scope of a configuration row.
 *
 * A row with no country applies to every market, and saying so plainly
 * matters: an operator who cannot tell whether a row is global will
 * deactivate a row that still applies to their city.
 */
export function CountryScopeBadge({
  countryName,
  countryCode,
  countryId,
}: {
  countryName?: string | null;
  countryCode?: string | null;
  countryId?: string | null;
}) {
  if (!countryId && !countryName) {
    return <span className="badge badge-gray">All countries</span>;
  }

  return (
    <span className="badge badge-blue">
      {countryName ?? 'Unknown country'}
      {countryCode ? ` (${countryCode})` : ''}
    </span>
  );
}

/** A small badge for any other scope-like value. */
export function ScopeBadge({ label, tone = 'gray' }: { label: string; tone?: string }) {
  return <span className={`badge badge-${tone}`}>{label}</span>;
}

/** Wraps a cell value with a tooltip-friendly wrapper. */
export function TruncatedText({ value, max = 80 }: { value: unknown; max?: number }) {
  const text = String(value ?? '');
  if (!text) return <span className="muted">—</span>;
  const clipped = text.length > max ? `${text.slice(0, max)}…` : text;
  return (
    <span className="truncate" title={text}>
      {clipped}
    </span>
  );
}

/** Renders a server-rendered side panel beside the table. */
export function SidePanel({ children }: { children: ReactNode }) {
  return <div className="config-side-panel">{children}</div>;
}
