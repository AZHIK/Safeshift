import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { ConfigurationFormDialog } from '@/components/configuration/configuration-form-dialog';
import { vehicleTypes } from '@/lib/configuration/resources';
import { toView } from '@/lib/configuration/view';

const resourceView = toView(vehicleTypes);

type SubmitFn = (values: Record<string, unknown>) => Promise<{ success: boolean }>;

const options = {
  countries: [
    { value: 'tz', label: 'Tanzania', secondary: 'TZ' },
    { value: 'ke', label: 'Kenya', secondary: 'KE' },
  ],
  vehicle_equipment: [{ value: 'tail_lift', label: 'Tail lift' }],
};

const initialValues = {
  country_id: 'tz',
  code: 'pickup_van',
  name: 'Pickup van',
  description: '',
  icon_url: '',
  capacity_kg_min: 500,
  capacity_kg_max: 1500,
  capacity_m3_min: null,
  capacity_m3_max: null,
  max_dimensions_cm: null,
  number_of_wheels: 4,
  requires_special_licence: false,
  requires_equipment: [],
  display_order: 1,
  is_active: true,
};

function renderDialog(
  overrides: Partial<React.ComponentProps<typeof ConfigurationFormDialog>> = {},
) {
  const props = {
    open: true,
    title: 'New Vehicle Type',
    fields: resourceView.fields,
    crossRules: resourceView.crossRules,
    options,
    initialValues,
    onSubmit: vi.fn<SubmitFn>(async () => ({ success: true })),
    onClose: vi.fn(),
    ...overrides,
  };
  const rendered = render(<ConfigurationFormDialog {...props} />);
  return { ...rendered, props };
}

describe('ConfigurationFormDialog', () => {
  it('renders the fields of the resource with their values', () => {
    renderDialog();

    expect(screen.getByLabelText('Code')).toHaveValue('pickup_van');
    expect(screen.getByLabelText('Name')).toHaveValue('Pickup van');
    expect(screen.getByLabelText('Minimum capacity (kg)')).toHaveValue(500);
    expect(screen.getByLabelText('Applies to')).toHaveValue('tz');
  });

  it('shows the required fields and the optional ones', () => {
    renderDialog();

    expect(screen.getByLabelText('Code')).toBeRequired();
    expect(screen.getByLabelText('Name')).toBeRequired();
    expect(screen.getByLabelText('Description')).not.toBeRequired();
  });

  it('refuses to submit without the required fields', async () => {
    const user = userEvent.setup();
    const { props } = renderDialog({
      initialValues: { ...initialValues, code: '', name: '' },
    });

    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('Code is required.')).toBeInTheDocument();
    expect(screen.getByText('Name is required.')).toBeInTheDocument();
    expect(props.onSubmit).not.toHaveBeenCalled();
  });

  it('refuses a maximum capacity below the minimum', async () => {
    const user = userEvent.setup();
    const { props } = renderDialog();

    const min = screen.getByLabelText('Minimum capacity (kg)');
    await user.clear(min);
    await user.type(min, '2000');

    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(
      await screen.findByText('Maximum capacity must not be smaller than the minimum.'),
    ).toBeInTheDocument();
    expect(props.onSubmit).not.toHaveBeenCalled();
  });

  it('refuses a capacity of zero', async () => {
    const user = userEvent.setup();
    const { props } = renderDialog();

    const min = screen.getByLabelText('Minimum capacity (kg)');
    await user.clear(min);
    await user.type(min, '0');

    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(await screen.findByText(/must be at least 1/i)).toBeInTheDocument();
    expect(props.onSubmit).not.toHaveBeenCalled();
  });

  it('submits the values when the form is valid', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn<SubmitFn>(async () => ({ success: true }));
    const onClose = vi.fn();
    renderDialog({ onClose, onSubmit });

    await user.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));
    expect(onSubmit.mock.calls[0][0]).toMatchObject({
      code: 'pickup_van',
      name: 'Pickup van',
      capacity_kg_min: 500,
    });
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it('shows the error the server returned', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn(async () => ({
      success: false,
      error: 'Another vehicle type already uses this code in this country.',
    }));
    const onClose = vi.fn();
    renderDialog({ onClose, onSubmit });

    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(
      await screen.findByText('Another vehicle type already uses this code in this country.'),
    ).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
  });

  it('shows the field errors the server returned', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn(async () => ({
      success: false,
      error: 'Please correct the highlighted fields.',
      fieldErrors: { code: 'This code is already taken.' },
    }));
    renderDialog({ onSubmit });

    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('This code is already taken.')).toBeInTheDocument();
  });

  it('closes without saving when the operator cancels', async () => {
    const user = userEvent.setup();
    const { props } = renderDialog();

    await user.click(screen.getByRole('button', { name: 'Cancel' }));

    expect(props.onClose).toHaveBeenCalled();
    expect(props.onSubmit).not.toHaveBeenCalled();
  });

  it('only shows the equipment that the catalogue offers', async () => {
    const user = userEvent.setup();
    renderDialog();

    await user.click(screen.getByRole('checkbox', { name: /Tail lift/ }));

    expect(screen.getByRole('checkbox', { name: /Tail lift/ })).toBeChecked();
  });

  it('shows the country scope of the row', () => {
    renderDialog();

    const select = screen.getByLabelText('Applies to') as HTMLSelectElement;
    expect(select.options[0].textContent).toBe('All countries');
    expect(select.options[1].textContent).toBe('Tanzania — TZ');
  });
});
