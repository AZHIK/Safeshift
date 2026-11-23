import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { secondFactorVerified } from '@/lib/second-factor';

const mfa = {
  listFactors: vi.fn(),
  unenroll: vi.fn(),
  enroll: vi.fn(),
  challengeAndVerify: vi.fn(),
};
const invoke = vi.fn();
const rpc = vi.fn();

vi.mock('@/lib/supabase/client', () => ({
  getBrowserClient: () => ({ auth: { mfa }, functions: { invoke }, rpc }),
}));

const { SecondFactorOptions } = await import('@/app/mfa/second-factor-options');

describe('secondFactorVerified', () => {
  it('trusts an aal2 session without asking the database', async () => {
    const client = {
      auth: { mfa: { getAuthenticatorAssuranceLevel: vi.fn(async () => ({ data: { currentLevel: 'aal2' } })) } },
      rpc: vi.fn(),
    };
    expect(await secondFactorVerified(client as never)).toBe(true);
    expect(client.rpc).not.toHaveBeenCalled();
  });

  it('accepts an email- or SMS-verified session reported by the database', async () => {
    const client = {
      auth: { mfa: { getAuthenticatorAssuranceLevel: vi.fn(async () => ({ data: { currentLevel: 'aal1' } })) } },
      rpc: vi.fn(async () => ({ data: { verified: true, method: 'sms' }, error: null })),
    };
    expect(await secondFactorVerified(client as never)).toBe(true);
    expect(client.rpc).toHaveBeenCalledWith('admin_second_factor_status');
  });

  it('fails closed when the database cannot answer', async () => {
    const client = {
      auth: { mfa: { getAuthenticatorAssuranceLevel: vi.fn(async () => ({ data: { currentLevel: 'aal1' } })) } },
      rpc: vi.fn(async () => ({ data: null, error: { message: 'down' } })),
    };
    expect(await secondFactorVerified(client as never)).toBe(false);
  });
});

describe('SecondFactorOptions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('offers all three methods and explains a missing phone number', () => {
    render(<SecondFactorOptions authenticators={[]} email="ka••••@example.com" phone={null} />);
    expect(screen.getByRole('tab', { name: 'Authenticator app' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Text message' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'Email' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('tab', { name: 'Text message' }));
    expect(screen.getByText(/No phone number is on your account/)).toBeInTheDocument();
  });

  it('shows a scannable QR code when setting up an authenticator', async () => {
    mfa.listFactors.mockResolvedValue({ data: { all: [{ id: 'old', factor_type: 'totp', status: 'unverified' }] } });
    mfa.unenroll.mockResolvedValue({ error: null });
    mfa.enroll.mockResolvedValue({
      data: { id: 'f1', totp: { qr_code: 'data:image/svg+xml;utf-8,<svg/>', secret: 'JBSWY3DPEHPK3PXP' } },
      error: null,
    });
    render(<SecondFactorOptions authenticators={[]} email={null} phone={null} />);
    fireEvent.click(screen.getByRole('button', { name: 'Set up authenticator app' }));

    const qr = await screen.findByAltText('QR code to add SafeShift to your authenticator app');
    expect(qr).toHaveAttribute('src', 'data:image/svg+xml;utf-8,<svg/>');
    expect(screen.getByText('JBSWY3DPEHPK3PXP')).toBeInTheDocument();
    // The stale unfinished setup was removed before enrolling again.
    expect(mfa.unenroll).toHaveBeenCalledWith({ factorId: 'old' });
    expect(mfa.enroll).toHaveBeenCalledWith(expect.objectContaining({ factorType: 'totp', issuer: 'SafeShift' }));
  });

  it('asks only for a code when an authenticator is already set up', () => {
    render(<SecondFactorOptions authenticators={[{ id: 'f1', label: 'Phone' }]} email={null} phone={null} />);
    expect(screen.queryByRole('button', { name: 'Set up authenticator app' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('6-digit code')).toBeInTheDocument();
  });

  it('sends an email code, then verifies it with the database', async () => {
    invoke.mockResolvedValue({ data: { data: { sent: true, to: 'ka••••@example.com' } }, error: null });
    rpc.mockResolvedValue({ data: true, error: null });
    const replace = vi.fn();
    Object.defineProperty(window, 'location', { value: { replace }, writable: true });

    render(<SecondFactorOptions authenticators={[]} email="ka••••@example.com" phone="+255 •••• 678" />);
    fireEvent.click(screen.getByRole('tab', { name: 'Email' }));
    fireEvent.click(screen.getByRole('button', { name: 'Send code' }));

    await screen.findByText(/We sent a code to/);
    expect(invoke).toHaveBeenCalledWith('admin-otp', { body: { channel: 'email' } });
    expect(screen.getByRole('button', { name: /Resend in/ })).toBeDisabled();

    fireEvent.change(screen.getByLabelText('6-digit code'), { target: { value: '12 34 56' } });
    fireEvent.click(screen.getByRole('button', { name: 'Verify' }));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('admin_verify_second_factor', { p_code: '123456' }));
    await waitFor(() => expect(replace).toHaveBeenCalledWith('/dashboard'));
  });

  it('shows the server reason when a code cannot be sent', async () => {
    invoke.mockResolvedValue({
      data: null,
      error: {
        message: 'Edge Function returned a non-2xx status code',
        context: { json: async () => ({ error: { message: 'a code was sent less than a minute ago' } }) },
      },
    });
    render(<SecondFactorOptions authenticators={[]} email={null} phone="+255 •••• 678" />);
    fireEvent.click(screen.getByRole('tab', { name: 'Text message' }));
    fireEvent.click(screen.getByRole('button', { name: 'Send code' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('a code was sent less than a minute ago');
    expect(invoke).toHaveBeenCalledWith('admin-otp', { body: { channel: 'sms' } });
  });
});
