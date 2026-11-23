import Link from 'next/link';

import { CellValue } from '@/components/cell-value';
import type { RecordColumn } from '@/lib/data-records';
import { entityHref } from '@/lib/entity-links';
import { referencedTable, type ReferenceLabels } from '@/lib/record-labels';

/** A reference value shown by the name of the row it points at, linked to it. */
export function ReferenceValue({
  column,
  value,
  labels,
  showId = false,
}: {
  column: RecordColumn;
  value: unknown;
  labels: ReferenceLabels;
  showId?: boolean;
}) {
  const v = String(value);
  const name = labels[column.column_name]?.[v];
  const table = referencedTable(column);
  const href = table ? entityHref(table, v) : null;
  const text = name ?? <CellValue value={value} />;
  return (
    <span>
      {href ? <Link href={href}>{text}</Link> : text}
      {showId && name ? <span className="mono small muted" style={{ display: 'block' }}>{v}</span> : null}
    </span>
  );
}
