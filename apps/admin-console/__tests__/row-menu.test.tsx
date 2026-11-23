import { fireEvent, render, screen, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { DataTable } from '@/components/data-table';
import { RowMenu } from '@/components/row-menu';

describe('RowMenu', () => {
  it('opens from the ⋮ button and lists every action', () => {
    render(
      <RowMenu
        label="Actions for Juma"
        items={[
          { kind: 'link', label: 'View details', href: '/users/1' },
          { kind: 'disabled', label: 'Edit or delete', note: 'Money records are append-only.' },
        ]}
      />,
    );
    const button = screen.getByRole('button', { name: 'Actions for Juma' });
    expect(button).toHaveAttribute('aria-expanded', 'false');
    fireEvent.click(button);
    const menu = screen.getByRole('menu');
    expect(within(menu).getByRole('menuitem', { name: 'View details' })).toHaveAttribute('href', '/users/1');
    expect(within(menu).getByText('Money records are append-only.')).toBeInTheDocument();
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  });

  it('asks for confirmation and a reason before a destructive action', () => {
    const action = vi.fn();
    render(
      <RowMenu
        items={[{ kind: 'form', label: 'Delete account', action, fields: { profile_id: 'p1' }, reason: 'Reason', confirm: 'This cannot be undone.', danger: true }]}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Actions' }));
    fireEvent.click(screen.getByRole('menuitem', { name: 'Delete account…' }));
    const dialog = screen.getByRole('dialog', { name: 'Delete account' });
    expect(within(dialog).getByText('This cannot be undone.')).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Reason')).toBeRequired();
    expect(dialog.querySelector('input[name="profile_id"]')).toHaveValue('p1');
    fireEvent.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(action).not.toHaveBeenCalled();
  });

  it('runs client callbacks for menus inside client tables', () => {
    const onSelect = vi.fn();
    render(<RowMenu items={[{ kind: 'button', label: 'Edit', onSelect }]} />);
    fireEvent.click(screen.getByRole('button', { name: 'Actions' }));
    fireEvent.click(screen.getByRole('menuitem', { name: 'Edit' }));
    expect(onSelect).toHaveBeenCalledOnce();
    expect(screen.queryByRole('menu')).not.toBeInTheDocument();
  });
});

describe('DataTable actions', () => {
  it('adds an actions column with one menu per row', () => {
    render(
      <DataTable
        columns={['Name']}
        rows={[['A'], ['B']]}
        actions={[<RowMenu key="a" label="Actions for A" items={[]} />, <RowMenu key="b" label="Actions for B" items={[]} />]}
      />,
    );
    expect(screen.getAllByRole('columnheader')).toHaveLength(2);
    expect(screen.getByRole('button', { name: 'Actions for A' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Actions for B' })).toBeInTheDocument();
  });
});
