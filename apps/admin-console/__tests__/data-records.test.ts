import { beforeEach, describe, expect, it, vi } from 'vitest';

const { rpc, permissions } = vi.hoisted(() => ({ rpc: vi.fn(), permissions: new Set<string>() }));
vi.mock('@/lib/supabase/server', () => ({ createClient: async () => ({ rpc }) }));
vi.mock('@/lib/auth', () => ({ getAdminSession: async () => ({ userId: 'u' }) }));
vi.mock('@/lib/configuration/guard', () => ({ getCallerPermissions: async () => ({ permissions }) }));
vi.mock('next/navigation', () => ({ redirect: (url: string) => { throw new Error(url); } }));
vi.mock('react', async (orig) => ({ ...(await orig<typeof import('react')>()), cache: <T>(fn: T) => fn }));

const {
  decodeKey, encodeKey, getRecordAccess, inputKind, keyOf, parseRecordForm, recordHref, requireRecordTable,
} = await import('@/lib/data-records');
const { entityHref } = await import('@/lib/entity-links');

type Col = Parameters<typeof inputKind>[0];
const col = (column_name: string, data_type: string, extra: Partial<Col> = {}): Col => ({
  column_name, data_type, is_nullable: true, has_default: false, is_primary_key: false,
  is_generated: false, references_table: null, enum_values: null, ...extra,
});
const form = (values: Record<string, string>) => {
  const data = new FormData();
  Object.entries(values).forEach(([k, v]) => data.set(k, v));
  return data;
};

describe('record keys', () => {
  it('round-trips single and composite keys through a URL-safe token', () => {
    const token = encodeKey({ role_name: 'super_admin', permission_key: 'manage/all+?' });
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(decodeKey(token)).toEqual({ role_name: 'super_admin', permission_key: 'manage/all+?' });
    expect(recordHref('cities', 'abc')).toBe(`/data/cities/${encodeKey({ id: 'abc' })}`);
    expect(keyOf({ id: 7, name: 'x' }, ['id'])).toEqual({ id: '7' });
  });

  it('rejects tokens that are not a flat key object', () => {
    for (const bad of ['%%%', encodeKey({} as never), Buffer.from('[1]').toString('base64url'),
      Buffer.from('{"id":{"x":1}}').toString('base64url')]) {
      expect(decodeKey(bad)).toBeNull();
    }
  });
});

describe('record forms', () => {
  const columns = [
    col('id', 'uuid', { is_primary_key: true, has_default: true, is_nullable: false }),
    col('name', 'text', { is_nullable: false }),
    col('seats', 'integer'),
    col('is_active', 'boolean', { is_nullable: false, has_default: true }),
    col('settings', 'jsonb'),
    col('kind', 'text', { enum_values: ['a', 'b'] }),
    col('slug', 'text', { is_generated: true }),
  ];

  it('picks an input for each type', () => {
    expect(columns.map(inputKind)).toEqual(['text', 'longtext', 'number', 'boolean', 'json', 'enum', 'longtext']);
    expect(inputKind(col('at', 'timestamp with time zone'))).toBe('timestamp');
    expect(inputKind(col('tags', 'text[]'))).toBe('json');
  });

  it('on create, leaves blanks out so database defaults apply', () => {
    const values = parseRecordForm(columns, form({
      'f:id': '', 'f:name': 'Truck', 'f:seats': '3', 'f:is_active': 'false', 'f:settings': '{"a":1}', 'f:kind': '', 'f:slug': 'x',
    }), 'create');
    expect(values).toEqual({ name: 'Truck', seats: 3, is_active: false, settings: { a: 1 } });
  });

  it('on edit, never sends keys, clears nullable blanks and keeps required ones', () => {
    const values = parseRecordForm(columns, form({
      'f:id': 'changed', 'f:name': '', 'f:seats': '', 'f:is_active': 'true', 'f:kind': 'b',
    }), 'edit');
    expect(values).toEqual({ seats: null, is_active: true, kind: 'b' });
  });

  it('explains bad numbers and JSON', () => {
    expect(() => parseRecordForm(columns, form({ 'f:seats': 'many' }), 'create')).toThrow('seats must be a number');
    expect(() => parseRecordForm(columns, form({ 'f:settings': '{' }), 'create')).toThrow('settings must be valid JSON');
  });
});

describe('record access', () => {
  beforeEach(() => {
    permissions.clear();
    rpc.mockReset();
  });

  it('lets a pricing manager edit tariffs only', async () => {
    permissions.add('manage_regulated_tariffs');
    const access = await getRecordAccess();
    expect(access.canManage).toBe(false);
    expect(access.allowed('regulated_tariffs')).toBe(true);
    expect(access.allowed('profiles')).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
    await expect(requireRecordTable('profiles')).rejects.toThrow('/dashboard');
    await expect(requireRecordTable('regulated_tariffs')).resolves.toBeUndefined();
  });

  it('gives manage_records every table and reports append-only ones', async () => {
    permissions.add('manage_records');
    rpc.mockResolvedValue({ data: [{ table_name: 'payments', write_block: 'Money records are append-only.' }, { table_name: 'cities', write_block: null }], error: null });
    const access = await getRecordAccess();
    expect(access.allowed('anything')).toBe(true);
    expect(access.blocked.get('payments')).toMatch(/append-only/);
    expect(access.blocked.has('cities')).toBe(false);
  });
});

describe('entityHref', () => {
  const id = '00000000-0000-4000-8000-000000000001';
  it('opens audited entities on their own screen or the record page', () => {
    expect(entityHref('profile', id)).toBe(`/users/${id}`);
    expect(entityHref('jobs', id)).toBe(`/jobs/${id}`);
    expect(entityHref('cities', id)).toBe(`/data/cities/${encodeKey({ id })}`);
    expect(entityHref('cities', 'not-a-uuid')).toBeNull();
    expect(entityHref('Bad Type', id)).toBeNull();
  });
});
