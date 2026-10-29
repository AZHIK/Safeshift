import { createClient } from './supabase/server';

export type AdminSession = {
  userId: string;
  email: string | null;
  name: string;
  role: string;
};

export async function getAdminSession(): Promise<AdminSession | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: role, error } = await supabase.rpc('admin_console_role');
  if (error || !role) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, display_name, email')
    .eq('id', user.id)
    .maybeSingle();

  return {
    userId: user.id,
    email: profile?.email ?? user.email ?? null,
    name: profile?.full_name ?? profile?.display_name ?? user.email ?? 'Admin',
    role: String(role),
  };
}

export function canSee(role: string, area: string): boolean {
  if (role === 'super_admin') return true;
  if (role === 'fleet_owner') {
    return ['dashboard', 'fleets', 'settings'].includes(area);
  }
  if (role === 'verification_admin') {
    return ['dashboard', 'verifications', 'users', 'drivers', 'settings'].includes(area);
  }
  if (role === 'support_agent') {
    return ['dashboard', 'users', 'drivers', 'jobs', 'disputes', 'support', 'incidents', 'data-requests', 'settings'].includes(area);
  }
  if (role === 'finance_admin') {
    return ['dashboard', 'payments', 'payouts', 'analytics', 'settings'].includes(area);
  }
  if (role === 'analyst') {
    return ['dashboard', 'users', 'drivers', 'jobs', 'payments', 'payouts', 'analytics', 'support', 'settings'].includes(area);
  }
  return ['dashboard', 'users', 'drivers', 'jobs', 'payments', 'payouts', 'disputes', 'support', 'incidents', 'pricing', 'promos', 'analytics', 'fleets', 'data-requests', 'verifications', 'settings', 'audit'].includes(area);
}
