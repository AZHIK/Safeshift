import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { ConfigurationTable, type ConfigRow } from '@/components/configuration/configuration-table';

const columns = [
  { key: 'code', label: 'Code', kind: 'code' as const, sortable: true },
  { key: 'name', label: 'Name' },
  { key: 'country_name', label: 'Country' },
  { key: 'capacity_kg_max', label: 'Max kg', kind: 'number' as const },
  { key: 'is_active', label: 'Status', kind: 'boolean' as const },
];

const rows: ConfigRow[] = [
  {
    id: 'row-1',
    code: 'pickup_van',
    name: 'Pickup van',
    country_id: null,
    country_name: null,
    capacity_kg_max: 1500,
    is_active: true,
  },
  {
    id: 'row-2',
    code: 'truck_7t',
    name: 'Seven tonne truck',
    country_id: 'country-1',
    countries: { name: 'Tanzania', iso_code: 'TZ' },
    capacity_kg_max: 7000,
    is_active: false,
  },
];

function renderTable(overrides: Partial<React.ComponentProps<typeof ConfigurationTable>> = {}) {
  const props = {
    columns,
    rows,
    onCreate: vi.fn(),
    onEdit: vi.fn(),
    onDeactivate: vi.fn(),
    onAudit: vi.fn(),
    ...overrides,
  };
  const view = render(<ConfigurationTable {...props} />);
  return { ...view, props };
}

describe('ConfigurationTable', () => {
  it('renders one row per record with its columns', () => {
    renderTable();

    expect(screen.getByText('pickup_van')).toBeInTheDocument();
    expect(screen.getByText('Pickup van')).toBeInTheDocument();
    expect(screen.getByText('Seven tonne truck')).toBeInTheDocument();
    expect(screen.getByText('1500')).toBeInTheDocument();
  });

  it('shows the country scope of a row', () => {
    renderTable();

    // A row with no country applies to every market.
    expect(screen.getByText('All countries')).toBeInTheDocument();
    expect(screen.getByText('Tanzania (TZ)')).toBeInTheDocument();
  });

  it('shows the status of a row', () => {
    renderTable();

    expect(screen.getByText('Active')).toBeInTheDocument();
    expect(screen.getByText('Inactive')).toBeInTheDocument();
  });

  it('shows the empty state when there are no rows', () => {
    renderTable({ rows: [], emptyMessage: 'No vehicle types yet.' });

    expect(screen.getByText('No vehicle types yet.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create the first one' })).toBeInTheDocument();
  });

  it('shows the loading skeleton while the rows are on their way', () => {
    const { container } = renderTable({ loading: true });

    expect(container.querySelectorAll('.skeleton').length).toBeGreaterThan(0);
    expect(screen.queryByText('pickup_van')).not.toBeInTheDocument();
  });

  it('groups the rows by the grouping column', () => {
    renderTable({
      groupBy: 'namespace',
      rows: [
        { id: 'row-1', namespace: 'booking', code: 'a', is_active: true },
        { id: 'row-2', namespace: 'booking', code: 'b', is_active: true },
        { id: 'row-3', namespace: 'errors', code: 'c', is_active: true },
      ],
    });

    const groupRows = screen.getAllByText('booking');
    expect(groupRows.length).toBe(1);
    expect(screen.getByText('errors')).toBeInTheDocument();
  });

  it('calls the row actions', async () => {
    const user = userEvent.setup();
    const { props } = renderTable();

    const firstRow = screen.getByText('pickup_van').closest('tr') as HTMLElement;
    await user.click(within(firstRow).getByRole('button', { name: 'Edit' }));
    expect(props.onEdit).toHaveBeenCalledWith(rows[0]);

    await user.click(within(firstRow).getByRole('button', { name: 'Deactivate' }));
    expect(props.onDeactivate).toHaveBeenCalledWith(rows[0]);

    await user.click(within(firstRow).getByRole('button', { name: 'Audit history' }));
    expect(props.onAudit).toHaveBeenCalledWith(rows[0]);
  });

  it('offers to activate a row that is not active', async () => {
    const user = userEvent.setup();
    const onActivate = vi.fn();
    renderTable({ onActivate });

    const secondRow = screen.getByText('truck_7t').closest('tr') as HTMLElement;
    await user.click(within(secondRow).getByRole('button', { name: 'Activate' }));

    expect(onActivate).toHaveBeenCalledWith(rows[1]);
  });

  it('hides the actions an administrator may not use', () => {
    renderTable({ canAudit: false, canDeactivate: false, canEdit: false });

    expect(screen.queryByRole('button', { name: 'Edit' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Deactivate' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Audit history' })).not.toBeInTheDocument();
  });
});
