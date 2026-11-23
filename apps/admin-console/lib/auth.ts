import { secondFactorVerified } from './second-factor';
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
  if (!(await secondFactorVerified(supabase))) redirect('/mfa');

  return {
    userId: user.id,
    email: profile?.email ?? user.email ?? null,
    name: profile?.full_name ?? profile?.display_name ?? user.email ?? 'Admin',
    role: String(role),
  };
});
