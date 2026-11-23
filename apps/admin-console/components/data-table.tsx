import type { ReactNode } from 'react';

export function DataTable({
  columns,
  rows,
  actions,
  empty = 'No records found.',
}: {
  columns: string[];
  rows: ReactNode[][];
  /** The ⋮ menu for each row, rendered in a final "Actions" column. */
  actions?: ReactNode[];
  empty?: string;
}) {
  if (rows.length === 0) {
    return <div className="table-empty">{empty}</div>;
  }
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column}>{column}</th>
            ))}
            {actions ? (
              <th className="col-actions">
                <span className="sr-only">Actions</span>
              </th>
            ) : null}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index}>
              {row.map((cell, cellIndex) => (
                <td key={cellIndex}>{cell}</td>
              ))}
              {actions ? <td className="col-actions">{actions[index] ?? null}</td> : null}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
