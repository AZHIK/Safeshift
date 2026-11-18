'use client';

import { useCallback, useMemo, useState, useTransition } from 'react';

import { ConfigurationTable, type ConfigRow } from '@/components/configuration/configuration-table';
import {
  ConfigurationSearchFilters,
  type ConfigurationFilterState,
} from '@/components/configuration/configuration-search-filters';
import { DeactivateConfirmDialog } from '@/components/configuration/deactivate-confirm-dialog';
import { AuditHistoryDrawer } from '@/components/configuration/audit-history-button';
import type { ConfigOption, ListFilters } from '@/lib/configuration/types';

/**
 * The Permissions Catalog.
 *
 * It is a different shape from the other configuration pages: the rows are
 * the grants between a role and a permission, so "creating" a row grants a
 * permission and "deleting" one revokes it. There is also a catalogue of the
 * permissions themselves, which only a super admin may extend.
 */
export function PermissionCatalogClient({
  rows,
  total,
  page,
  pageSize,
  roles,
  permissions,
  rolePermissions,
  callerPermissions,
  isSuperAdmin,
  actions,
}: {
  rows: ConfigRow[];
  total: number;
  page: number;
  pageSize: number;
  roles: ConfigOption[];
  permissions: ConfigOption[];
  rolePermissions: Record<string, string[]>;
  callerPermissions: string[];
  isSuperAdmin: boolean;
  actions: {
    list: (filters: ListFilters) => Promise<{
      success: boolean;
      rows?: ConfigRow[];
      total?: number;
      page?: number;
      error?: string;
    }>;
    grant: (values: { role_name: string; permission_key: string }) => Promise<{
      success: boolean;
      error?: string;
    }>;
    revoke: (
      roleName: string,
      permissionKey: string,
    ) => Promise<{
      success: boolean;
      error?: string;
    }>;
    createPermission: (values: {
      permission_key: string;
      description: string;
      category: string;
    }) => Promise<{ success: boolean; error?: string }>;
    audit: (
      id: string,
      query: { limit?: number },
    ) => Promise<
      {
        entry_id: string;
        created_at: string;
        actor_id: string | null;
        actor_name: string;
        action: string;
        old_value: unknown;
        new_value: unknown;
        source: string;
      }[]
    >;
  };
}) {
  const [currentRows, setCurrentRows] = useState(rows);
  const [currentTotal, setCurrentTotal] = useState(total);
  const [currentPage, setCurrentPage] = useState(page);
  const [filters, setFilters] = useState<ConfigurationFilterState>({
    search: '',
    status: 'all',
    country: 'all',
    extra: {},
  });
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const [granting, setGranting] = useState(false);
  const [roleName, setRoleName] = useState(roles[0]?.value ?? '');
  const [permissionKey, setPermissionKey] = useState('');
  const [creatingPermission, setCreatingPermission] = useState(false);
  const [newKey, setNewKey] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newCategory, setNewCategory] = useState('platform');
  const [revoking, setRevoking] = useState<ConfigRow | null>(null);
  const [auditing, setAuditing] = useState<ConfigRow | null>(null);

  const selectedRolePermissions = useMemo(
    () => rolePermissions[roleName] ?? [],
    [roleName, rolePermissions],
  );

  const refresh = async (nextPage = currentPage) => {
    setError(null);
    const result = await actions.list({
      search: filters.search || undefined,
      page: nextPage,
      pageSize,
    });
    if (!result.success) {
      setError(result.error ?? 'The grants could not be read.');
      return;
    }
    setCurrentRows(result.rows ?? []);
    setCurrentTotal(result.total ?? 0);
    setCurrentPage(result.page ?? nextPage);
  };

  const submitGrant = async () => {
    setError(null);
    const result = await actions.grant({ role_name: roleName, permission_key: permissionKey });
    if (result.success) {
      setNotice(`Granted ${permissionKey} to ${roleName}.`);
      setPermissionKey('');
      setGranting(false);
      await refresh();
    } else {
      setError(result.error ?? 'The permission could not be granted.');
    }
  };

  const submitPermission = async () => {
    setError(null);
    const result = await actions.createPermission({
      permission_key: newKey.trim(),
      description: newDescription.trim(),
      category: newCategory,
    });
    if (result.success) {
      setNotice(`Created the permission ${newKey.trim()}.`);
      setNewKey('');
      setNewDescription('');
      setCreatingPermission(false);
      await refresh();
    } else {
      setError(result.error ?? 'The permission could not be created.');
    }
  };

  const submitRevoke = async () => {
    if (!revoking) return;
    setError(null);
    const result = await actions.revoke(
      String(revoking.role_name),
      String(revoking.permission_key),
    );
    if (result.success) {
      setNotice(`Removed ${revoking.permission_key} from ${revoking.role_name}.`);
      setRevoking(null);
      await refresh();
    } else {
      setError(result.error ?? 'The permission could not be revoked.');
    }
  };

  const loadAudit = useCallback(
    async (query: { limit?: number }) => {
      if (!auditing) return [];
      return actions.audit(String(auditing.id), query);
    },
    [actions, auditing],
  );

  return (
    <>
      <div className="notice notice-info">
        <strong>Changes to role permissions affect all users with that role immediately.</strong>{' '}
        Revoking a permission takes effect the next time a permission check runs.
      </div>

      <div className="config-toolbar-row">
        <ConfigurationSearchFilters
          hasStatus={false}
          onChange={(next) => {
            setFilters(next);
            startTransition(() => {
              void refresh(1);
            });
          }}
          state={filters}
        />
        <div className="inline">
          <button className="btn" onClick={() => setCreatingPermission(true)} type="button">
            New permission
          </button>
          <button className="btn btn-primary" onClick={() => setGranting(true)} type="button">
            Grant a permission
          </button>
        </div>
      </div>

      {error ? <div className="notice notice-error">{error}</div> : null}
      {notice ? <div className="notice notice-ok">{notice}</div> : null}

      <div className="config-split">
        <div className="card">
          <ConfigurationTable
            canAudit
            canCreate={false}
            columns={[
              { key: 'role_name', label: 'Role', sortable: true },
              { key: 'permission_key', label: 'Permission', kind: 'code', sortable: true },
              { key: 'description', label: 'Description' },
              { key: 'category', label: 'Category' },
            ]}
            emptyMessage="No permission grants yet."
            loading={isPending}
            onAudit={(row) => setAuditing(row)}
            onCreate={() => setGranting(true)}
            onDeactivate={(row) => setRevoking(row)}
            onEdit={() => undefined}
            rows={currentRows}
          />
          <div className="pagination">
            <span className="small muted">{currentTotal} grants</span>
          </div>
        </div>

        <div className="card card-pad">
          <h3 className="card-title">Permissions of a role</h3>
          <p className="card-sub">Read only. This is what the role grants today.</p>
          <div className="field" style={{ marginTop: 10 }}>
            <label htmlFor="catalog-role">Role</label>
            <select
              className="input"
              id="catalog-role"
              onChange={(event) => setRoleName(event.target.value)}
              value={roleName}
            >
              {roles.map((role) => (
                <option key={role.value} value={role.value}>
                  {role.label}
                </option>
              ))}
            </select>
          </div>
          <div className="chip-list" style={{ marginTop: 10 }}>
            {selectedRolePermissions.length === 0 ? (
              <span className="small muted">This role grants no permissions.</span>
            ) : (
              selectedRolePermissions.map((permission) => (
                <span className="chip" key={permission}>
                  {permission}
                </span>
              ))
            )}
          </div>
          {roleName === 'super_admin' ? (
            <p className="small muted" style={{ marginTop: 10 }}>
              The super admin role holds every permission in the catalogue, including the ones added
              later.
            </p>
          ) : null}
        </div>
      </div>

      {granting ? (
        <div className="dialog-backdrop" role="dialog" aria-modal="true">
          <div className="dialog">
            <div className="dialog-head">
              <h2 className="dialog-title">Grant a permission</h2>
              <button className="btn btn-sm" onClick={() => setGranting(false)} type="button">
                ✕
              </button>
            </div>
            <div className="dialog-body">
              <div className="field">
                <label htmlFor="grant-role">Role</label>
                <select
                  className="input"
                  id="grant-role"
                  onChange={(event) => setRoleName(event.target.value)}
                  value={roleName}
                >
                  {roles.map((role) => (
                    <option key={role.value} value={role.value}>
                      {role.label}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="grant-permission">Permission</label>
                <select
                  className="input"
                  id="grant-permission"
                  onChange={(event) => setPermissionKey(event.target.value)}
                  value={permissionKey}
                >
                  <option value="">Choose a permission</option>
                  {permissions.map((permission) => (
                    <option key={permission.value} value={permission.value}>
                      {permission.secondary
                        ? `${permission.value} — ${permission.secondary}`
                        : permission.value}
                    </option>
                  ))}
                </select>
              </div>
              {permissionKey && !callerPermissions.includes(permissionKey) ? (
                <div className="notice notice-info">
                  You do not hold <strong>{permissionKey}</strong> yourself. You are granting a
                  permission you cannot use.
                </div>
              ) : null}
              {roleName === 'super_admin' && !isSuperAdmin ? (
                <div className="notice notice-error">
                  Only a super admin may change the super admin role.
                </div>
              ) : null}
            </div>
            <div className="dialog-foot">
              <button className="btn" onClick={() => setGranting(false)} type="button">
                Cancel
              </button>
              <button
                className="btn btn-primary"
                disabled={!permissionKey}
                onClick={() => void submitGrant()}
                type="button"
              >
                Grant
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {creatingPermission ? (
        <div className="dialog-backdrop" role="dialog" aria-modal="true">
          <div className="dialog">
            <div className="dialog-head">
              <h2 className="dialog-title">New permission</h2>
              <button
                className="btn btn-sm"
                onClick={() => setCreatingPermission(false)}
                type="button"
              >
                ✕
              </button>
            </div>
            <div className="dialog-body">
              <div className="field">
                <label htmlFor="new-permission-key">Permission key</label>
                <input
                  className="input"
                  id="new-permission-key"
                  onChange={(event) => setNewKey(event.target.value)}
                  placeholder="manage_something"
                  value={newKey}
                />
              </div>
              <div className="field">
                <label htmlFor="new-permission-description">Description</label>
                <input
                  className="input"
                  id="new-permission-description"
                  onChange={(event) => setNewDescription(event.target.value)}
                  placeholder="What the permission allows"
                  value={newDescription}
                />
              </div>
              <div className="field">
                <label htmlFor="new-permission-category">Category</label>
                <input
                  className="input"
                  id="new-permission-category"
                  onChange={(event) => setNewCategory(event.target.value)}
                  value={newCategory}
                />
              </div>
            </div>
            <div className="dialog-foot">
              <button className="btn" onClick={() => setCreatingPermission(false)} type="button">
                Cancel
              </button>
              <button
                className="btn btn-primary"
                disabled={!newKey.trim() || !newDescription.trim()}
                onClick={() => void submitPermission()}
                type="button"
              >
                Create
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <DeactivateConfirmDialog
        error={error}
        onClose={() => setRevoking(null)}
        onConfirm={() => void submitRevoke()}
        open={Boolean(revoking)}
        recordName={revoking ? `${revoking.permission_key} → ${revoking.role_name}` : ''}
        singular="permission grant"
        impact="The permission stops applying to every holder of that role immediately."
      />

      <AuditHistoryDrawer
        load={loadAudit}
        onClose={() => setAuditing(null)}
        open={Boolean(auditing)}
        recordLabel={auditing ? `${auditing.permission_key} → ${auditing.role_name}` : ''}
      />
    </>
  );
}
