'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

import { defaultValues, rowToValues } from '@/lib/configuration/validation';
import type { ConfigFieldValues, ConfigOption, ListFilters } from '@/lib/configuration/types';
import type { ConfigView } from '@/lib/configuration/view';

import { AuditHistoryDrawer, type AuditEntry, type AuditQuery } from './audit-history-button';
import {
  ConfigurationFormDialog,
  type FormSubmitResult,
  type ProfileHit,
} from './configuration-form-dialog';
import {
  ConfigurationSearchFilters,
  type ConfigurationFilterState,
} from './configuration-search-filters';
import { ConfigurationTable, type ConfigRow } from './configuration-table';
import { DeactivateConfirmDialog, type ReferenceCount } from './deactivate-confirm-dialog';

export type ConfigurationActions = {
  list: (filters: ListFilters) => Promise<{
    success: boolean;
    rows?: ConfigRow[];
    total?: number;
    page?: number;
    pageSize?: number;
    error?: string;
  }>;
  create: (values: ConfigFieldValues) => Promise<FormSubmitResult>;
  update: (id: string, values: ConfigFieldValues) => Promise<FormSubmitResult>;
  deactivate: (id: string, reason: string) => Promise<FormSubmitResult>;
  remove: (id: string) => Promise<FormSubmitResult>;
  audit: (id: string, query: AuditQuery) => Promise<AuditEntry[]>;
  references?: (id: string) => Promise<ReferenceCount[]>;
  searchProfiles?: (query: string) => Promise<ProfileHit[]>;
};

/**
 * The client half of every configuration page.
 *
 * One component drives all twenty pages: it owns the filter state, calls the
 * page's server actions, and renders the table and the dialogs. The page
 * itself stays a server component that checks the permission and loads the
 * first page of rows.
 */
export function ConfigurationClient({
  view,
  options,
  initialRows,
  initialTotal,
  initialPage,
  initialCountry = 'all',
  pageSize = 25,
  actions,
  sidePanel,
  preview,
  createLabel,
  countries,
}: {
  view: ConfigView;
  options: Record<string, ConfigOption[]>;
  initialRows: ConfigRow[];
  initialTotal: number;
  initialPage: number;
  /** The country the list is filtered to on arrival. */
  initialCountry?: string;
  pageSize?: number;
  actions: ConfigurationActions;
  sidePanel?: React.ReactNode;
  preview?: { titleField: string; bodyField: string; variablesField?: string };
  createLabel?: string;
  countries?: ConfigOption[];
}) {
  const [rows, setRows] = useState<ConfigRow[]>(initialRows);
  const [total, setTotal] = useState(initialTotal);
  const [page, setPage] = useState(initialPage);
  const [filters, setFilters] = useState<ConfigurationFilterState>({
    search: '',
    status: 'all',
    country: initialCountry,
    extra: {},
  });
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [editing, setEditing] = useState<{ row: ConfigRow | null } | null>(null);
  const [deactivating, setDeactivating] = useState<ConfigRow | null>(null);
  const [deactivatingReferences, setDeactivatingReferences] = useState<ReferenceCount[]>([]);
  const [deactivateError, setDeactivateError] = useState<string | null>(null);
  const [auditing, setAuditing] = useState<ConfigRow | null>(null);

  const pageCount = Math.max(1, Math.ceil(total / pageSize));

  const refresh = useCallback(
    async (next: ConfigurationFilterState, nextPage: number) => {
      setLoading(true);
      setError(null);
      try {
        const result = await actions.list({
          search: next.search || undefined,
          status: next.status,
          country: next.country,
          page: nextPage,
          pageSize,
          extra: next.extra,
        });
        if (!result.success) {
          setError(result.error ?? 'The list could not be read.');
          return;
        }
        setRows(result.rows ?? []);
        setTotal(result.total ?? 0);
        setPage(result.page ?? nextPage);
      } catch (caught) {
        setError(caught instanceof Error ? caught.message : 'The list could not be read.');
      } finally {
        setLoading(false);
      }
    },
    [actions, pageSize],
  );

  // Debounce the free-text search so a keystroke does not become a query.
  useEffect(() => {
    const timer = setTimeout(() => {
      void refresh(filters, 1);
    }, 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters.search, filters.status, filters.country, filters.extra]);

  const handleFilterChange = (next: ConfigurationFilterState) => {
    setFilters(next);
    setPage(1);
  };

  const handleCreate = () => {
    setEditing({ row: null });
  };

  const handleEdit = (row: ConfigRow) => {
    setEditing({ row });
  };

  const handleSubmit = async (values: ConfigFieldValues) => {
    const isEdit = editing?.row ? true : false;
    const id = editing?.row ? String(editing.row.id) : null;

    const result = isEdit && id ? await actions.update(id, values) : await actions.create(values);

    if (result.success) {
      setNotice(isEdit ? 'The record was updated.' : 'The record was created.');
      await refresh(filters, isEdit ? page : 1);
    }
    return result;
  };

  const openDeactivate = async (row: ConfigRow) => {
    setDeactivating(row);
    setDeactivateError(null);
    setDeactivatingReferences([]);
    if (actions.references) {
      try {
        setDeactivatingReferences(await actions.references(String(row.id)));
      } catch {
        setDeactivatingReferences([]);
      }
    }
  };

  const handleDeactivate = async (reason: string) => {
    if (!deactivating) return;
    setDeactivateError(null);
    const id = String(deactivating.id);
    const result = view.hardDelete
      ? await actions.remove(id)
      : await actions.deactivate(id, reason);

    if (result.success) {
      setNotice(view.hardDelete ? 'The record was removed.' : 'The record was deactivated.');
      setDeactivating(null);
      await refresh(filters, page);
    } else {
      setDeactivateError(result.error ?? 'The record could not be deactivated.');
    }
  };

  const loadAudit = useCallback(
    async (query: AuditQuery) => {
      if (!auditing) return [];
      return actions.audit(String(auditing.id), query);
    },
    [actions, auditing],
  );

  const formValues = useMemo(() => {
    if (!editing) return {};
    return editing.row ? rowToValues(view, editing.row) : defaultValues(view);
  }, [editing, view]);

  const rowLabel = (row: ConfigRow) => {
    const name = row.name ?? row.code ?? row.flag_key ?? row.title ?? row.key ?? row.id;
    return String(name);
  };

  return (
    <>
      <div className="config-toolbar-row">
        <ConfigurationSearchFilters
          countries={countries}
          filters={view.filters}
          hasStatus={Boolean(view.softDelete)}
          onChange={handleFilterChange}
          state={filters}
        />
        <button className="btn btn-primary" onClick={handleCreate} type="button">
          {createLabel ?? `New ${view.singular}`}
        </button>
      </div>

      {error ? <div className="notice notice-error">{error}</div> : null}
      {notice ? <div className="notice notice-ok">{notice}</div> : null}

      <div className={sidePanel ? 'config-split' : undefined}>
        <div className="card">
          <ConfigurationTable
            canAudit
            canCreate
            canDeactivate
            canEdit
            columns={view.columns}
            emptyMessage={`No ${view.pluralTitle.toLowerCase()} yet.`}
            groupBy={view.groupBy}
            loading={loading}
            onAudit={(row) => setAuditing(row)}
            onCreate={handleCreate}
            onDeactivate={(row) => void openDeactivate(row)}
            onEdit={handleEdit}
            rowAction={view.rowAction}
            rows={rows}
          />
          <div className="pagination">
            <span className="small muted">
              {total === 0
                ? 'No rows'
                : `Showing ${(page - 1) * pageSize + 1}–${Math.min(
                    page * pageSize,
                    total,
                  )} of ${total}`}
            </span>
            <div className="inline">
              <button
                className="btn btn-sm"
                disabled={page <= 1}
                onClick={() => {
                  const next = page - 1;
                  setPage(next);
                  void refresh(filters, next);
                }}
                type="button"
              >
                Previous
              </button>
              <span className="small">
                Page {page} of {pageCount}
              </span>
              <button
                className="btn btn-sm"
                disabled={page >= pageCount}
                onClick={() => {
                  const next = page + 1;
                  setPage(next);
                  void refresh(filters, next);
                }}
                type="button"
              >
                Next
              </button>
            </div>
          </div>
        </div>

        {sidePanel ? <div className="config-side-panel">{sidePanel}</div> : null}
      </div>

      {editing ? (
        <ConfigurationFormDialog
          description={view.description}
          key={editing.row ? String(editing.row.id) : 'new'}
          fields={view.fields}
          crossRules={view.crossRules}
          initialValues={formValues}
          onClose={() => setEditing(null)}
          onSubmit={handleSubmit}
          open
          options={options}
          preview={preview}
          searchProfiles={actions.searchProfiles}
          title={
            editing.row
              ? `Edit ${view.singularTitle}: ${rowLabel(editing.row)}`
              : `New ${view.singularTitle}`
          }
        />
      ) : null}

      {deactivating ? (
        <DeactivateConfirmDialog
          error={deactivateError}
          key={String(deactivating.id)}
          onClose={() => setDeactivating(null)}
          onConfirm={(reason) => void handleDeactivate(reason)}
          open
          recordName={rowLabel(deactivating)}
          references={deactivatingReferences}
          singular={view.singular}
        />
      ) : null}

      <AuditHistoryDrawer
        load={loadAudit}
        onClose={() => setAuditing(null)}
        open={Boolean(auditing)}
        recordLabel={auditing ? rowLabel(auditing) : ''}
      />
    </>
  );
}
