import { beforeEach, expect, it, vi } from 'vitest';
import { suspendAccountAction, reactivateAccountAction, suspendDriverAction, reinstateDriverAction, setFleetActiveAction } from '@/app/(console)/users/actions';

const { rpc, requireArea, revalidatePath } = vi.hoisted(() => ({ rpc: vi.fn(), requireArea: vi.fn(), revalidatePath: vi.fn() }));
vi.mock('@/lib/supabase/server', () => ({ createClient: async () => ({ rpc }) }));
vi.mock('@/lib/guard', () => ({ requireArea }));
vi.mock('next/cache', () => ({ revalidatePath }));
vi.mock('next/navigation', () => ({ redirect: (url: string) => { throw new Error(url); } }));
const id = '00000000-0000-4000-8000-000000000001';
const form = (values: Record<string, string>) => {
  const data = new FormData();
  Object.entries(values).forEach(([key, value]) => data.set(key, value));
  return data;
};
beforeEach(() => { vi.resetAllMocks(); rpc.mockResolvedValue({ error: null }); });
it.each([
  [suspendAccountAction, 'users', 'admin_suspend_account', {profile_id:id,reason:' Fraud '}, {p_profile_id:id,p_reason:'Fraud'}],
  [reactivateAccountAction, 'users', 'admin_reactivate_account', {profile_id:id}, {p_profile_id:id,p_note:null}],
  [suspendDriverAction, 'drivers', 'admin_suspend_driver', {driver_id:id,reason:'Review'}, {p_driver_id:id,p_reason:'Review'}],
  [reinstateDriverAction, 'drivers', 'admin_reinstate_driver', {driver_id:id,note:'Cleared'}, {p_driver_id:id,p_note:'Cleared'}],
  [setFleetActiveAction, 'fleets', 'admin_set_fleet_active', {fleet_id:id,active:'false',reason:'Review'}, {p_fleet_id:id,p_active:false,p_reason:'Review'}],
  [setFleetActiveAction, 'fleets', 'admin_set_fleet_active', {fleet_id:id,active:'true'}, {p_fleet_id:id,p_active:true,p_reason:null}],
] as const)('submits %s through the authorized RPC', async (action, area, name, fields, args) => {
  await expect(action(form({...fields,back:'//external.example'}))).rejects.toThrow(new RegExp('^/'+area+'(?:/[^?]+)?\\?ok='));
  expect(requireArea).toHaveBeenCalledWith(area);
  expect(rpc).toHaveBeenCalledWith(name, args);
  expect(revalidatePath).toHaveBeenCalledWith('/fleets','layout');
});
it.each([{fleet_id:id,active:'maybe',reason:'Review'}, {fleet_id:id,active:'false',reason:' '}, {fleet_id:'bad',active:'true',reason:''}])('rejects an invalid fleet transition', async (fields) => {
  await expect(setFleetActiveAction(form(fields))).rejects.toThrow('/fleets?error=');
  expect(rpc).not.toHaveBeenCalled();
});
it('surfaces a denied change without invalidating data', async () => {
  rpc.mockResolvedValue({error:{message:'Permission denied'}});
  await expect(setFleetActiveAction(form({fleet_id:id,active:'true'}))).rejects.toThrow('/fleets?error=Permission%20denied');
  expect(revalidatePath).not.toHaveBeenCalled();
});
