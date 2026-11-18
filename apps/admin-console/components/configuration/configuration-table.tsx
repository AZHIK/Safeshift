'use client';

import Link from 'next/link';
import { Fragment } from 'react';

import { formatDate } from '@/lib/format';
import type { ConfigColumn, ConfigRowAction } from '@/lib/configuration/types';

import { CountryScopeBadge, TruncatedText } from './country-scope-badge';

export type ConfigRow = Record<string, unknown>;

/** Renders one cell according to the column's kind. */
export function ConfigCell({ column, row }: { column: ConfigColumn; row: ConfigRow }) {
  const value = row[column.key];

  if (column.key === 'pricing_plan_count') {
    const count = Number(value ?? 0);
    return (
      <span className={`badge ${count > 0 ? 'badge-green' : 'badge-amber'}`}>
        {count > 0 ? `${count} plan${count === 1 ? '' : 's'}` : 'No pricing'}
      </span>
    );
  }

  if (column.key === 'country_name' || column.key === 'country_id') {
    const country = row.countries as { name?: string; iso_code?: string } | null;
    return (
      <CountryScopeBadge
        countryCode={country?.iso_code}
        countryId={(row.country_id as string | null) ?? undefined}
        countryName={country?.name}
      />
    );
  }

  switch (column.kind) {
    case 'code':
      return <span className="mono small">{value ? String(value) : '—'}</span>;
    case 'number':
      return (
        <span className="small mono">
          {value === null || value === undefined || value === '' ? '—' : String(value)}
        </span>
      );
    case 'boolean':
      if (column.key === 'is_enabled') {
        return (
          <span className={`badge ${value ? 'badge-green' : 'badge-gray'}`}>
            {value ? 'Enabled' : 'Disabled'}
          </span>
        );
      }
      return (
        <span className={`badge ${value ? 'badge-green' : 'badge-gray'}`}>
          {value ? 'Active' : 'Inactive'}
        </span>
      );
    case 'date':
      return <span className="small nowrap">{formatDate(value)}</span>;
    case 'json':
      return <TruncatedText max={60} value={value ? JSON.stringify(value) : ''} />;
    default:
      if (
        column.key === 'value' ||
        column.key === 'body_template' ||
        column.key === 'description'
      ) {
        return <TruncatedText value={value} />;
      }
      if (value === null || value === undefined || value === '') {
        return <span className="muted">—</span>;
      }
      return <span className="small">{String(value)}</span>;
  }
}

/**
 * The table of configuration rows.
 *
 * The rows arrive already filtered, sorted and paginated by the server; this
 * component renders them and owns the row actions.
 */
export function ConfigurationTable({
  columns,
  rows,
  loading = false,
  groupBy,
  emptyMessage,
  onCreate,
  onEdit,
  onDeactivate,
  onAudit,
  onActivate,
  rowAction,
  canCreate = true,
  canEdit = true,
  canDeactivate = true,
  canAudit = true,
}: {
  columns: ConfigColumn[];
  rows: ConfigRow[];
  loading?: boolean;
  groupBy?: string;
  emptyMessage?: string;
  onCreate: () => void;
  onEdit: (row: ConfigRow) => void;
  onDeactivate: (row: ConfigRow) => void;
  onAudit: (row: ConfigRow) => void;
  onActivate?: (row: ConfigRow) => void;
  rowAction?: ConfigRowAction;
  canCreate?: boolean;
  canEdit?: boolean;
  canDeactivate?: boolean;
  canAudit?: boolean;
}) {
  if (loading) {
    return (
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              {columns.map((column) => (
                <th key={column.key}>{column.label}</th>
              ))}
              <th aria-label="Actions" />
            </tr>
          </thead>
          <tbody>
            {Array.from({ length: 4 }).map((_, rowIndex) => (
              <tr key={rowIndex}>
                {columns.map((column) => (
                  <td key={column.key}>
                    <span className="skeleton" />
                  </td>
                ))}
                <td>
                  <span className="skeleton" />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  if (rows.length === 0) {
    return (
      <div className="config-empty">
        <p>{emptyMessage ?? 'No records yet.'}</p>
        {canCreate ? (
          <button className="btn btn-primary" onClick={onCreate} type="button">
            Create the first one
          </button>
        ) : null}
      </div>
    );
  }

  const groups = groupBy
    ? rows.reduce<Record<string, ConfigRow[]>>((accumulator, row) => {
        const key = String(row[groupBy] ?? '—');
        (accumulator[key] ??= []).push(row);
        return accumulator;
      }, {})
    : null;

  const renderRow = (row: ConfigRow) => {
    const isActive = row.is_active === true;
    return (
      <tr key={String(row.id ?? '')}>
        {columns.map((column) => (
          <td key={column.key}>
            <ConfigCell column={column} row={row} />
          </td>
        ))}
        <td>
          <div className="table-actions">
            {rowAction && row.id ? (
              <Link className="btn btn-sm" href={rowAction.href.replace('{id}', String(row.id))}>
                {rowAction.label}
              </Link>
            ) : null}
            {canEdit ? (
              <button className="btn btn-sm" onClick={() => onEdit(row)} type="button">
                Edit
              </button>
            ) : null}
            {canDeactivate ? (
              isActive ? (
                <button className="btn btn-sm" onClick={() => onDeactivate(row)} type="button">
                  Deactivate
                </button>
              ) : onActivate ? (
                <button className="btn btn-sm" onClick={() => onActivate(row)} type="button">
                  Activate
                </button>
              ) : null
            ) : null}
            {canAudit ? (
              <button
                aria-label="Audit history"
                className="btn btn-sm"
                onClick={() => onAudit(row)}
                title="Audit history"
                type="button"
              >
                Audit
              </button>
            ) : null}
          </div>
        </td>
      </tr>
    );
  };

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
            <th aria-label="Actions" />
          </tr>
        </thead>
        <tbody>
          {groups
            ? Object.entries(groups).map(([group, groupRows]) => (
                <Fragment key={group}>
                  <tr className="config-group-row">
                    <td colSpan={columns.length + 1}>{group}</td>
                  </tr>
                  {groupRows.map(renderRow)}
                </Fragment>
              ))
            : rows.map(renderRow)}
        </tbody>
      </table>
    </div>
  );
}
