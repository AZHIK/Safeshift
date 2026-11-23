import { accountStatusAction, deleteAccountAction, deleteRecordAction } from '@/app/(console)/data/actions';
import { encodeKey, getRecordAccess, type RecordKey } from '@/lib/data-records';

import { type MenuItem, RowMenu } from './row-menu';

/** People are removed with the account action, which keeps their history. */
const ACCOUNT_TABLES = new Set(['profiles', 'drivers', 'customers']);

/**
 * The ⋮ menu for one row: the page's own actions first, then view, edit and
 * delete for the underlying record when the caller manages records.
 */
export async function RecordActions({
  table,
  id,
  recordKey,
  viewHref,
  items = [],
  label,
  generic = 'all',
}: {
  table: string;
  /** Primary key value when the key is a single "id" column. */
  id?: unknown;
  recordKey?: RecordKey;
  /** The page's own detail screen, when it has one. */
  viewHref?: string;
  items?: MenuItem[];
  label?: string;
  /** 'view' when the page already offers its own edit and delete. */
  generic?: 'all' | 'view';
}) {
  const access = await getRecordAccess();
  const key = recordKey ?? (id === null || id === undefined || id === '' ? null : { id: String(id) });
  const token = key ? encodeKey(key) : null;
  const menu: MenuItem[] = [];

  if (viewHref) menu.push({ kind: 'link', label: 'View details', href: viewHref });
  menu.push(...items);

  if (access.allowed(table) && token) {
    const base = `/data/${table}/${token}`;
    menu.push({ kind: 'link', label: viewHref ? 'View all fields' : 'View', href: base });
    const block = access.blocked.get(table);
    if (generic === 'view') {
      // The page's own actions cover editing.
    } else if (block) {
      menu.push({ kind: 'disabled', label: 'Edit or delete', note: block });
    } else {
      menu.push({ kind: 'link', label: 'Edit', href: `${base}/edit` });
      if (!ACCOUNT_TABLES.has(table)) {
        menu.push({
          kind: 'form',
          label: 'Delete',
          action: deleteRecordAction,
          fields: { table, key: token },
          confirm: 'This permanently deletes the record. If other records still use it, the delete is refused and nothing changes.',
          danger: true,
        });
      }
    }
  }
  return <RowMenu items={menu} label={label ?? 'Actions'} />;
}

/** Deactivate / reactivate and delete for a person (users and drivers tables). */
export function accountItems({
  profileId,
  isActive,
  driver,
}: {
  profileId: string;
  isActive: boolean;
  /** Driver dispatch status, when the row is a driver. */
  driver?: { suspended: boolean };
}): MenuItem[] {
  const items: MenuItem[] = [];
  if (driver) {
    items.push(
      driver.suspended
        ? { kind: 'form', label: 'Reinstate driver', action: accountStatusAction, fields: { profile_id: profileId, op: 'reinstate_driver' }, confirm: 'The driver can go online and receive jobs again.' }
        : { kind: 'form', label: 'Deactivate driver', action: accountStatusAction, fields: { profile_id: profileId, op: 'suspend_driver' }, reason: 'Reason (kept in the audit log)', confirm: 'The driver goes offline and receives no jobs. Their account still works.', danger: true },
    );
  }
  items.push(
    isActive
      ? { kind: 'form', label: 'Deactivate account', action: accountStatusAction, fields: { profile_id: profileId, op: 'suspend_account' }, reason: 'Reason (kept in the audit log)', confirm: 'Signs them out everywhere and blocks sign-in until reactivated.', danger: true }
      : { kind: 'form', label: 'Reactivate account', action: accountStatusAction, fields: { profile_id: profileId, op: 'reactivate_account' }, confirm: 'They can sign in again.' },
    {
      kind: 'form',
      label: 'Delete account',
      action: deleteAccountAction,
      fields: { profile_id: profileId },
      reason: 'Reason (kept in the audit log)',
      confirm: 'Accounts with no trips or payments are removed completely. Otherwise their name, phone and email are erased and sign-in is blocked for good, while trips and payments stay for the records. This cannot be undone.',
      danger: true,
    },
  );
  return items;
}
