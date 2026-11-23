import { formatDate } from '@/lib/format';

const ISO_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-/i;

/** A database value, readable in a table cell. */
export function CellValue({ value }: { value: unknown }) {
  if (value === null || value === undefined || value === '') return <span className="muted">—</span>;
  if (typeof value === 'boolean') return <span>{value ? 'Yes' : 'No'}</span>;
  if (typeof value === 'object') {
    const text = JSON.stringify(value);
    return <span className="mono small" title={text}>{text.length > 60 ? `${text.slice(0, 60)}…` : text}</span>;
  }
  const text = String(value);
  if (ISO_RE.test(text)) return <span className="small">{formatDate(text)}</span>;
  if (UUID_RE.test(text)) return <span className="mono small" title={text}>{text.slice(0, 8)}</span>;
  return <span title={text.length > 80 ? text : undefined}>{text.length > 80 ? `${text.slice(0, 80)}…` : text}</span>;
}
