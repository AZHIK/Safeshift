import { cache } from 'react';
import { redirect } from 'next/navigation';

import { createClient } from './supabase/server';

export type AdminSession = {
  userId: string;
  email: string | null;
  name: string;
  role: string;
};

export const getAdminSession = cache(async (): Promise<AdminSession | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const [{ data: role, error }, { data: profile }] = await Promise.all([
    supabase.rpc('admin_console_role'),
    supabase
      .from('profiles')
      .select('full_name, display_name, email')
      .eq('id', user.id)
      .maybeSingle(),
  ]);
  if (error || !role) return null;
  const { data: assurance } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (assurance?.currentLevel !== 'aal2') redirect('/mfa');

  return {
    userId: user.id,
    email: profile?.email ?? user.email ?? null,
    name: profile?.full_name ?? profile?.display_name ?? user.email ?? 'Admin',
    role: String(role),
  };
});

export function canSee(role: string, area: string): boolean {
  if (role === 'super_admin') return true;
  if (role === 'fleet_owner') {
    return ['dashboard', 'fleets', 'settings'].includes(area);
  }
  if (role === 'verification_admin') {
    return ['dashboard', 'verifications', 'users', 'drivers', 'settings'].includes(area);
  }
  if (role === 'support_agent') {
    return [
      'dashboard',
      'users',
      'drivers',
      'jobs',
      'disputes',
      'support',
      'incidents',
      'data-requests',
      'settings',
    ].includes(area);
  }
  if (role === 'finance_admin') {
    return ['dashboard', 'payments', 'payouts', 'analytics', 'settings'].includes(area);
  }
  if (role === 'analyst') {
    return [
      'dashboard',
      'users',
      'drivers',
      'jobs',
      'payments',
      'payouts',
      'analytics',
      'support',
      'settings',
    ].includes(area);
  }
  // operations_admin and any other staff role. The catalogue is included
  // because managing the vehicle and cargo catalogues is an operations duty;
  // the writes themselves are still gated by the 'manage_vehicle_catalog' and
  // 'manage_cargo_catalog' permissions in the database.
  return [
    'dashboard',
    'users',
    'drivers',
    'jobs',
    'payments',
    'payouts',
    'disputes',
    'support',
    'incidents',
    'pricing',
    'promos',
    'analytics',
    'fleets',
    'data-requests',
    'verifications',
    'catalog',
    'settings',
    'audit',
  ].includes(area);
}
