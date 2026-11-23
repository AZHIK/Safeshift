import { beforeEach, expect, it, vi } from 'vitest';

const { rpc, requireArea, requireRecordTable, revalidatePath, referer } = vi.hoisted(() => ({
  rpc: vi.fn(), requireArea: vi.fn(), requireRecordTable: vi.fn(), revalidatePath: vi.fn(),
  referer: { value: 'http://console.test/drivers?page=2' as string | null },
}));
vi.mock('@/lib/supabase/server', () => ({ createClient: async () => ({ rpc }) }));
vi.mock('@/lib/guard', () => ({ requireArea }));
vi.mock('next/cache', () => ({ revalidatePath }));
vi.mock('next/navigation', () => ({ redirect: (url: string) => { throw new Error(url); } }));
vi.mock('next/headers', () => ({
  headers: async () => new Map([['referer', referer.value], ['host', 'console.test']].filter(([, v]) => v) as [string, string][]),
}));
vi.mock('@/lib/data-records', async (orig) => ({ ...(await orig<typeof import('@/lib/data-records')>()), requireRecordTable }));

const { accountStatusAction, createRecordAction, deleteAccountAction, deleteRecordAction, updateRecordAction } =
  await import('@/app/(console)/data/actions');
const { encodeKey } = await import('@/lib/data-records');

const id = '00000000-0000-4000-8000-000000000001';
const form = (values: Record<string, string>) => {
  const data = new FormData();
  Object.entries(values).forEach(([k, v]) => data.set(k, v));
  return data;
};
const columns = [
  { column_name: 'id', data_type: 'uuid', is_nullable: false, has_default: true, is_primary_key: true, is_generated: false, references_table: null, enum_values: null },
  { column_name: 'name', data_type: 'text', is_nullable: false, has_default: false, is_primary_key: false, is_generated: false, references_table: null, enum_values: null },
];
const flash = (path: string, kind: string, text: RegExp) =>
  new RegExp(`^${path.replace(/[?/]/g, '\\$&')}\\?(?:.*&)?${kind}=${text.source}`);

beforeEach(() => {
  vi.resetAllMocks();
  referer.value = 'http://console.test/drivers?page=2';
  rpc.mockImplementation(async (name: string) =>
    name === 'admin_record_columns' ? { data: columns, error: null } : { data: { id, name: 'Dar' }, error: null });
});

it('creates a record with the table guard and opens it', async () => {
  await expect(createRecordAction(form({ table: 'cities', 'f:id': '', 'f:name': 'Dar' })))
    .rejects.toThrow(flash(`/data/cities/${encodeKey({ id })}`, 'done', /Record/));
  expect(requireRecordTable).toHaveBeenCalledWith('cities');
  expect(rpc).toHaveBeenCalledWith('admin_record_insert', { p_table: 'cities', p_values: { name: 'Dar' } });
});

it('refuses table names that are not identifiers before touching the database', async () => {
  await expect(createRecordAction(form({ table: 'cities;drop' }))).rejects.toThrow('/data?failed=');
  expect(rpc).not.toHaveBeenCalled();
});

it('saves edits by key and reports database errors on the edit page', async () => {
  const key = encodeKey({ id });
  await expect(updateRecordAction(form({ table: 'cities', key, 'f:name': 'Arusha' })))
    .rejects.toThrow(flash(`/data/cities/${key}`, 'done', /Changes/));
  expect(rpc).toHaveBeenCalledWith('admin_record_update', { p_table: 'cities', p_key: { id }, p_values: { name: 'Arusha' } });

  rpc.mockImplementation(async (name: string) =>
    name === 'admin_record_columns' ? { data: columns, error: null } : { data: null, error: { message: 'name is required' } });
  await expect(updateRecordAction(form({ table: 'cities', key, 'f:name': 'x' })))
    .rejects.toThrow(flash(`/data/cities/${key}/edit`, 'failed', /name/));
});

it('deletes and returns to the page the menu was on, never another host', async () => {
  const key = encodeKey({ id });
  await expect(deleteRecordAction(form({ table: 'cities', key }))).rejects.toThrow(/^\/drivers\?page=2&done=Record/);
  referer.value = 'https://evil.example/steal';
  await expect(deleteRecordAction(form({ table: 'cities', key }))).rejects.toThrow(/^\/data\/cities\?done=/);
  referer.value = `http://console.test/data/cities/${key}`;
  await expect(deleteRecordAction(form({ table: 'cities', key }))).rejects.toThrow(/^\/data\/cities\?done=/);
});

it('deletes an account with a reason and says whether history was kept', async () => {
  rpc.mockResolvedValue({ data: 'anonymized', error: null });
  await expect(deleteAccountAction(form({ profile_id: id, reason: 'Asked to be forgotten' })))
    .rejects.toThrow(/\/drivers\?page=2&done=.*trips/);
  expect(rpc).toHaveBeenCalledWith('admin_delete_account', { p_profile_id: id, p_reason: 'Asked to be forgotten' });

  await expect(deleteAccountAction(form({ profile_id: id, reason: ' ' }))).rejects.toThrow(/failed=Give/);
  referer.value = `http://console.test/users/${id}`;
  rpc.mockResolvedValue({ data: 'deleted', error: null });
  await expect(deleteAccountAction(form({ profile_id: id, reason: 'Duplicate' }))).rejects.toThrow(/^\/users\?done=Account/);
});

it.each([
  ['suspend_account', 'users', 'admin_suspend_account', { p_profile_id: id, p_reason: 'Fraud' }],
  ['reactivate_account', 'users', 'admin_reactivate_account', { p_profile_id: id, p_note: null }],
  ['suspend_driver', 'drivers', 'admin_suspend_driver', { p_driver_id: id, p_reason: 'Fraud' }],
  ['reinstate_driver', 'drivers', 'admin_reinstate_driver', { p_driver_id: id, p_note: null }],
])('row menu %s goes through its own permission and RPC', async (op, area, fn, args) => {
  rpc.mockResolvedValue({ error: null });
  const reason = op.startsWith('suspend') ? 'Fraud' : '';
  await expect(accountStatusAction(form({ profile_id: id, op, reason }))).rejects.toThrow(/done=/);
  expect(requireArea).toHaveBeenCalledWith(area);
  expect(rpc).toHaveBeenCalledWith(fn, args);
});

it('requires a reason to deactivate and rejects unknown operations', async () => {
  await expect(accountStatusAction(form({ profile_id: id, op: 'suspend_account', reason: '' }))).rejects.toThrow(/failed=Give/);
  await expect(accountStatusAction(form({ profile_id: id, op: 'drop_everything' }))).rejects.toThrow(/failed=Unknown/);
  expect(rpc).not.toHaveBeenCalled();
});
