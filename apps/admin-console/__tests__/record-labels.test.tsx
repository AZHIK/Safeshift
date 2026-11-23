import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

vi.mock('@/lib/supabase/server', () => ({ createClient: vi.fn() }));

import { ReferenceSelect } from '@/components/reference-select';
import { fieldLabel, type RecordColumn } from '@/lib/data-records';
import { entityTable } from '@/lib/entity-links';
import { disambiguate, referenceColumns, referencedTable } from '@/lib/record-labels';

const column = (over: Partial<RecordColumn>): RecordColumn => ({
  column_name: 'city_id',
  data_type: 'uuid',
  is_nullable: true,
  has_default: false,
  is_primary_key: false,
  is_generated: false,
  references_table: 'public.cities',
  enum_values: null,
  ...over,
});

describe('reference helpers', () => {
  it('labels reference fields by what they point at', () => {
    expect(fieldLabel('country_id')).toBe('Country');
    expect(fieldLabel('owner_profile_id')).toBe('Owner profile');
  });

  it('strips the public schema and ignores other schemas', () => {
    expect(referencedTable(column({}))).toBe('cities');
    expect(referencedTable(column({ references_table: 'cities' }))).toBe('cities');
    expect(referencedTable(column({ references_table: 'auth.users' }))).toBeNull();
  });

  it('only treats foreign-key columns as references', () => {
    expect(referenceColumns([column({}), column({ column_name: 'name', references_table: null })])).toHaveLength(1);
  });

  it('tells apart rows with the same name', () => {
    const out = disambiguate([
      { value: '00000000-0000-0000-0000-00000000aaaa', label: 'Asha' },
      { value: '00000000-0000-0000-0000-00000000bbbb', label: 'Asha' },
      { value: '00000000-0000-0000-0000-00000000cccc', label: 'Juma' },
    ]);
    expect(out.map((o) => o.label)).toEqual(['Asha (#aaaa)', 'Asha (#bbbb)', 'Juma']);
  });

  it('maps audited entity types to tables', () => {
    expect(entityTable('profile')).toBe('profiles');
    expect(entityTable('regulated_tariffs')).toBe('regulated_tariffs');
    expect(entityTable('bad name!')).toBeNull();
  });
});

describe('ReferenceSelect', () => {
  const base = {
    id: 'f',
    name: 'f:city_id',
    table: 'pricing_plans',
    column: 'city_id',
    required: false,
    blankLabel: 'None',
  };

  it('shows names and submits the id', () => {
    const search = vi.fn();
    render(
      <ReferenceSelect {...base} defaultValue="c2" search={search}
        choices={{ options: [{ value: 'c1', label: 'Arusha' }, { value: 'c2', label: 'Dar es Salaam' }], more: false }} />,
    );
    const select = screen.getByRole('combobox') as HTMLSelectElement;
    expect(select.value).toBe('c2');
    expect(screen.getByRole('option', { name: 'Dar es Salaam' })).toBeTruthy();
    expect(screen.queryByRole('searchbox')).toBeNull();
    expect(search).not.toHaveBeenCalled();
  });

  it('searches large tables and keeps the current choice', async () => {
    const search = vi.fn().mockResolvedValue({ options: [{ value: 'p9', label: 'Zawadi' }], more: false });
    render(
      <ReferenceSelect {...base} defaultValue="p1" search={search}
        choices={{ options: [{ value: 'p1', label: 'Asha' }], more: true }} />,
    );
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'zaw' } });
    await waitFor(() => expect(screen.getByRole('option', { name: 'Zawadi' })).toBeTruthy());
    expect(search).toHaveBeenCalledWith('pricing_plans', 'city_id', 'zaw');
    expect(screen.getByRole('option', { name: 'Asha' })).toBeTruthy();
    expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('p1');
  });
});
