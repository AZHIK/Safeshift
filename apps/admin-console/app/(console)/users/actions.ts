'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Only console paths: no scheme, no host, no protocol-relative "//". */
const BACK_RE = /^\/(users|drivers|fleets)(\/[0-9a-f-]{36})?$/i;

function go(path: string, kind: 'ok' | 'error', message: string): never {
  redirect(`${path}?${kind}=${encodeURIComponent(message)}`);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

function backPath(formData: FormData, fallback: string): string {
  const back = field(formData, 'back');
  return BACK_RE.test(back) ? back : fallback;
}

async function call(back: string, name: string, args: Record<string, unknown>, ok: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc(name, args);
  if (error) go(back, 'error', error.message);
  revalidatePath('/users', 'layout');
  revalidatePath('/drivers', 'layout');
  revalidatePath('/fleets', 'layout');
  go(back, 'ok', ok);
}

/** Blocks sign-in, ends sessions and marks the account inactive. */
export async function suspendAccountAction(formData: FormData) {
  await requireArea('users');
  const id = field(formData, 'profile_id');
  const back = backPath(formData, UUID_RE.test(id) ? `/users/${id}` : '/users');
  if (!UUID_RE.test(id)) go(back, 'error', 'Missing or invalid account.');
  const reason = field(formData, 'reason');
  if (reason.length < 3) go(back, 'error', 'Give a reason of at least 3 characters.');
  await call(back, 'admin_suspend_account', { p_profile_id: id, p_reason: reason },
    'Account suspended. The user is signed out and cannot sign in.');
}

export async function reactivateAccountAction(formData: FormData) {
  await requireArea('users');
  const id = field(formData, 'profile_id');
  const back = backPath(formData, UUID_RE.test(id) ? `/users/${id}` : '/users');
  if (!UUID_RE.test(id)) go(back, 'error', 'Missing or invalid account.');
  await call(back, 'admin_reactivate_account', { p_profile_id: id, p_note: field(formData, 'note') || null },
    'Account reactivated. The user can sign in again.');
}

/** Stops dispatch to a driver; the account itself stays usable. */
export async function suspendDriverAction(formData: FormData) {
  await requireArea('drivers');
  const id = field(formData, 'driver_id');
  const back = backPath(formData, UUID_RE.test(id) ? `/drivers/${id}` : '/drivers');
  if (!UUID_RE.test(id)) go(back, 'error', 'Missing or invalid driver.');
  const reason = field(formData, 'reason');
  if (reason.length < 3) go(back, 'error', 'Give a reason of at least 3 characters.');
  await call(back, 'admin_suspend_driver', { p_driver_id: id, p_reason: reason },
    'Driver suspended. They are offline and receive no jobs.');
}

export async function reinstateDriverAction(formData: FormData) {
  await requireArea('drivers');
  const id = field(formData, 'driver_id');
  const back = backPath(formData, UUID_RE.test(id) ? `/drivers/${id}` : '/drivers');
  if (!UUID_RE.test(id)) go(back, 'error', 'Missing or invalid driver.');
  await call(back, 'admin_reinstate_driver', { p_driver_id: id, p_note: field(formData, 'note') || null },
    'Driver reinstated.');
}

export async function setFleetActiveAction(formData: FormData) {
  await requireArea('fleets');
  const id = field(formData, 'fleet_id');
  const back = backPath(formData, '/fleets');
  if (!UUID_RE.test(id)) go(back, 'error', 'Missing or invalid fleet.');
  const active = field(formData, 'active') === 'true';
  const reason = field(formData, 'reason');
  if (!active && reason.length < 3) go(back, 'error', 'Give a reason for suspending this fleet.');
  await call(back, 'admin_set_fleet_active', { p_fleet_id: id, p_active: active, p_reason: reason || null },
    active ? 'Fleet reactivated.' : 'Fleet suspended.');
}
