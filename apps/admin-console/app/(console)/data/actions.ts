'use server';

import { revalidatePath } from 'next/cache';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';

import {
  decodeKey,
  encodeKey,
  FormValueError,
  isTableName,
  parseRecordForm,
  type RecordColumn,
  requireRecordTable,
} from '@/lib/data-records';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

/** Appends ?done= / ?failed= to a console path, keeping its other parameters. */
function withFlash(path: string, kind: 'done' | 'failed', message: string): string {
  const url = new URL(path, 'http://console.local');
  url.searchParams.delete('done');
  url.searchParams.delete('failed');
  url.searchParams.set(kind, message);
  return url.pathname + url.search;
}

/** The page the action came from, if it is a console path; never another host. */
async function referrerPath(fallback: string): Promise<string> {
  const h = await headers();
  const referer = h.get('referer');
  const host = h.get('host');
  if (!referer) return fallback;
  try {
    const url = new URL(referer);
    if (host && url.host !== host) return fallback;
    return url.pathname.startsWith('/') && !url.pathname.startsWith('//') ? url.pathname + url.search : fallback;
  } catch {
    return fallback;
  }
}

async function target(formData: FormData) {
  const table = field(formData, 'table');
  if (!isTableName(table)) redirect(withFlash('/data', 'failed', 'Unknown table.'));
  await requireRecordTable(table);
  return table;
}

async function columnsOf(table: string): Promise<RecordColumn[]> {
  const { data, error } = await (await createClient()).rpc('admin_record_columns', { p_table: table });
  if (error) redirect(withFlash(`/data/${table}`, 'failed', error.message));
  return (data ?? []) as RecordColumn[];
}

export async function createRecordAction(formData: FormData) {
  const table = await target(formData);
  const columns = await columnsOf(table);
  let values: Record<string, unknown>;
  try {
    values = parseRecordForm(columns, formData, 'create');
  } catch (error) {
    if (error instanceof FormValueError) redirect(withFlash(`/data/${table}/new`, 'failed', error.message));
    throw error;
  }
  const { data, error } = await (await createClient()).rpc('admin_record_insert', { p_table: table, p_values: values });
  if (error) redirect(withFlash(`/data/${table}/new`, 'failed', error.message));
  const row = (data ?? {}) as Record<string, unknown>;
  const pk = columns.filter((c) => c.is_primary_key).map((c) => c.column_name);
  revalidatePath('/', 'layout');
  const key = Object.fromEntries(pk.map((c) => [c, String(row[c] ?? '')]));
  redirect(withFlash(`/data/${table}/${encodeKey(key)}`, 'done', 'Record created.'));
}

export async function updateRecordAction(formData: FormData) {
  const table = await target(formData);
  const token = field(formData, 'key');
  const key = decodeKey(token);
  if (!key) redirect(withFlash(`/data/${table}`, 'failed', 'Unknown record.'));
  const columns = await columnsOf(table);
  let values: Record<string, unknown>;
  try {
    values = parseRecordForm(columns, formData, 'edit');
  } catch (error) {
    if (error instanceof FormValueError) redirect(withFlash(`/data/${table}/${token}/edit`, 'failed', error.message));
    throw error;
  }
  const { error } = await (await createClient()).rpc('admin_record_update', {
    p_table: table,
    p_key: key,
    p_values: values,
  });
  if (error) redirect(withFlash(`/data/${table}/${token}/edit`, 'failed', error.message));
  revalidatePath('/', 'layout');
  redirect(withFlash(`/data/${table}/${token}`, 'done', 'Changes saved.'));
}

export async function deleteRecordAction(formData: FormData) {
  const table = await target(formData);
  const token = field(formData, 'key');
  const key = decodeKey(token);
  let back = await referrerPath(`/data/${table}`);
  // Never return to the page of the record that no longer exists.
  if (back.split('?')[0].startsWith(`/data/${table}/${token}`)) back = `/data/${table}`;
  if (!key) redirect(withFlash(back, 'failed', 'Unknown record.'));
  const { error } = await (await createClient()).rpc('admin_record_delete', { p_table: table, p_key: key });
  if (error) redirect(withFlash(back, 'failed', error.message));
  revalidatePath('/', 'layout');
  redirect(withFlash(back, 'done', 'Record deleted.'));
}

/**
 * Deletes a person. Without history they are removed completely; with jobs,
 * payments or tickets their personal data is erased and sign-in blocked.
 */
export async function deleteAccountAction(formData: FormData) {
  const id = field(formData, 'profile_id');
  let back = await referrerPath('/users');
  if (UUID_RE.test(id) && back.includes(id)) back = back.startsWith('/drivers') ? '/drivers' : '/users';
  if (!UUID_RE.test(id)) redirect(withFlash(back, 'failed', 'Missing or invalid account.'));
  const reason = field(formData, 'reason');
  if (reason.length < 3) redirect(withFlash(back, 'failed', 'Give a reason of at least 3 characters.'));
  const { data, error } = await (await createClient()).rpc('admin_delete_account', {
    p_profile_id: id,
    p_reason: reason,
  });
  if (error) redirect(withFlash(back, 'failed', error.message));
  revalidatePath('/', 'layout');
  redirect(
    withFlash(
      back,
      'done',
      data === 'deleted'
        ? 'Account deleted.'
        : 'Account deleted. Their personal data was erased; trips and payments are kept for the records.',
    ),
  );
}

/** Suspend / reactivate / reinstate from a row menu, returning to the same page. */
export async function accountStatusAction(formData: FormData) {
  const id = field(formData, 'profile_id');
  const op = field(formData, 'op');
  const back = await referrerPath('/users');
  if (!UUID_RE.test(id)) redirect(withFlash(back, 'failed', 'Missing or invalid account.'));
  const reason = field(formData, 'reason');
  const calls: Record<string, [string, Record<string, unknown>, string, string]> = {
    suspend_account: ['admin_suspend_account', { p_profile_id: id, p_reason: reason }, 'users', 'Account deactivated. They are signed out and cannot sign in.'],
    reactivate_account: ['admin_reactivate_account', { p_profile_id: id, p_note: reason || null }, 'users', 'Account reactivated.'],
    suspend_driver: ['admin_suspend_driver', { p_driver_id: id, p_reason: reason }, 'drivers', 'Driver deactivated. They are offline and receive no jobs.'],
    reinstate_driver: ['admin_reinstate_driver', { p_driver_id: id, p_note: reason || null }, 'drivers', 'Driver reinstated.'],
  };
  const call = calls[op];
  if (!call) redirect(withFlash(back, 'failed', 'Unknown action.'));
  const [fn, args, area, ok] = call;
  await requireArea(area);
  if (op.startsWith('suspend') && reason.length < 3) redirect(withFlash(back, 'failed', 'Give a reason of at least 3 characters.'));
  const { error } = await (await createClient()).rpc(fn, args);
  if (error) redirect(withFlash(back, 'failed', error.message));
  revalidatePath('/', 'layout');
  redirect(withFlash(back, 'done', ok));
}
