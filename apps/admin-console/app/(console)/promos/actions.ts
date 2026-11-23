'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireArea } from '@/lib/guard';
import { toSaveArgs, validatePromo, type PromoForm } from '@/lib/promos/promo';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function go(path: string, kind: 'ok' | 'error', message: string): never {
  redirect(`${path}?${kind}=${encodeURIComponent(message)}`);
}

export type SavePromoResult = { ok: true; id: string } | { ok: false; errors: string[] };

/** Creates (promoId null) or updates a promo with its eligibility rules. */
export async function savePromoAction(promoId: string | null, form: PromoForm): Promise<SavePromoResult> {
  await requireArea('promos');
  if (promoId !== null && !UUID_RE.test(promoId)) return { ok: false, errors: ['Invalid promo.'] };

  const errors = validatePromo(form);
  if (errors.length > 0) return { ok: false, errors };

  const { promo, rules } = toSaveArgs(form);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_save_promo', {
    p_promo_id: promoId,
    p_promo: promo,
    p_rules: rules,
  });
  if (error) return { ok: false, errors: [error.message] };
  revalidatePath('/promos', 'layout');
  return { ok: true, id: String(data) };
}

/** Pauses or resumes a promo without touching anything else. */
export async function setPromoActiveAction(formData: FormData) {
  await requireArea('promos');
  const promoId = String(formData.get('promo_id') ?? '');
  const back = String(formData.get('back') ?? '') === 'detail' ? `/promos/${promoId}` : '/promos';
  if (!UUID_RE.test(promoId)) go('/promos', 'error', 'Missing or invalid promo.');
  const active = formData.get('active') === 'true';

  const supabase = await createClient();
  const { error } = await supabase.from('promo_codes').update({ is_active: active }).eq('id', promoId);
  if (error) go(back, 'error', error.message);
  revalidatePath('/promos', 'layout');
  go(back, 'ok', active ? 'Promo resumed.' : 'Promo paused. Customers can no longer apply it.');
}

/** Deletes a promo that was never redeemed. */
export async function deletePromoAction(formData: FormData) {
  await requireArea('promos');
  const promoId = String(formData.get('promo_id') ?? '');
  if (!UUID_RE.test(promoId)) go('/promos', 'error', 'Missing or invalid promo.');

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_delete_promo', { p_promo_id: promoId });
  if (error) go(`/promos/${promoId}`, 'error', error.message);
  revalidatePath('/promos', 'layout');
  go('/promos', 'ok', 'Promo deleted.');
}
