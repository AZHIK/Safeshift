'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { requireArea } from '@/lib/guard';
import { toSavePayload, validateDraft, type PricingDraft } from '@/lib/pricing/draft';
import { createClient } from '@/lib/supabase/server';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CODE_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

function go(path: string, kind: 'ok' | 'error', message: string): never {
  redirect(`${path}?${kind}=${encodeURIComponent(message)}`);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

function uuidField(formData: FormData, name: string, back: string): string {
  const value = field(formData, name);
  if (!UUID_RE.test(value)) go(back, 'error', `Missing or invalid ${name.replace(/_/g, ' ')}.`);
  return value;
}

function money(formData: FormData, name: string): number {
  const raw = field(formData, name);
  return raw === '' ? 0 : Number(raw);
}

const planPath = (planId: string) => `/pricing/${planId}`;
const versionPath = (planId: string, versionId: string) => `/pricing/${planId}/versions/${versionId}`;

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

/** Creates a plan and publishes its first version with the base rates. */
export async function createPricingPlanAction(formData: FormData) {
  await requireArea('pricing');
  const back = '/pricing';
  const countryId = uuidField(formData, 'country_id', back);
  const cityId = uuidField(formData, 'city_id', back);
  const vehicleTypeId = uuidField(formData, 'vehicle_type_id', back);
  const code = field(formData, 'code').toLowerCase();
  const name = field(formData, 'name');
  if (!CODE_RE.test(code)) {
    go(back, 'error', 'Code must be lowercase letters and digits separated by hyphens, e.g. dar-pickup.');
  }
  if (!name) go(back, 'error', 'Name is required.');

  const vatPercent = field(formData, 'vat_percent');
  const rates = {
    base_fare: money(formData, 'base_fare'),
    per_km_rate: money(formData, 'per_km_rate'),
    per_min_rate: money(formData, 'per_min_rate'),
    minimum_charge: money(formData, 'minimum_charge'),
    vat_rate: vatPercent === '' ? 0.18 : Number(vatPercent) / 100,
  };
  if (Object.values(rates).some((n) => !Number.isFinite(n) || n < 0) || rates.vat_rate > 1) {
    go(back, 'error', 'Rates must be numbers of 0 or more, and VAT at most 100 %.');
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_create_pricing_plan', {
    p_country_id: countryId,
    p_city_id: cityId,
    p_vehicle_type_id: vehicleTypeId,
    p_code: code,
    p_name: name,
    p_description: field(formData, 'description') || null,
    p_service_zone_id: null,
    p_currency_code: field(formData, 'currency_code') || 'TZS',
    p_base_fare: rates.base_fare,
    p_per_km_rate: rates.per_km_rate,
    p_per_min_rate: rates.per_min_rate,
    p_minimum_charge: rates.minimum_charge,
    p_vat_rate: rates.vat_rate,
  });
  if (error) go(back, 'error', error.message);
  revalidatePath('/pricing');
  go(planPath(String(data)), 'ok', 'Plan created and version 1 published.');
}

/** Name, description and active flag only; rates change through drafts. */
export async function updatePricingPlanAction(formData: FormData) {
  await requireArea('pricing');
  const planId = uuidField(formData, 'plan_id', '/pricing');
  const back = planPath(planId);
  const name = field(formData, 'name');
  if (!name) go(back, 'error', 'Name is required.');

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_update_pricing_plan', {
    p_plan_id: planId,
    p_name: name,
    p_description: field(formData, 'description') || null,
    p_is_active: formData.get('is_active') === 'on' || formData.get('is_active') === 'true',
  });
  if (error) go(back, 'error', error.message);
  revalidatePath('/pricing');
  revalidatePath(back);
  go(back, 'ok', 'Plan details saved.');
}

/** Deletes a plan that has never priced a quote. */
export async function deletePricingPlanAction(formData: FormData) {
  await requireArea('pricing');
  const planId = uuidField(formData, 'plan_id', '/pricing');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_delete_pricing_plan', { p_plan_id: planId });
  if (error) {
    const message = /used in quotes/.test(error.message)
      ? 'This plan has priced quotes, so it is kept for the record. Deactivate it instead.'
      : error.message;
    go(planPath(planId), 'error', message);
  }
  revalidatePath('/pricing');
  go('/pricing', 'ok', 'Plan deleted.');
}

// ---------------------------------------------------------------------------
// Drafts
// ---------------------------------------------------------------------------

/** Opens a draft from the latest published version, or from an older one. */
export async function createDraftAction(formData: FormData) {
  await requireArea('pricing');
  const planId = uuidField(formData, 'plan_id', '/pricing');
  const source = field(formData, 'source_version_id');
  if (source && !UUID_RE.test(source)) go(planPath(planId), 'error', 'Invalid source version.');

  const supabase = await createClient();
  const { data, error } = await supabase.rpc('admin_create_pricing_draft', {
    p_plan_id: planId,
    p_source_version_id: source || null,
  });
  if (error) go(planPath(planId), 'error', error.message);
  revalidatePath(planPath(planId));
  go(
    versionPath(planId, String(data)),
    'ok',
    source ? 'Draft created from the older version. Review it, then publish.' : 'Draft created.',
  );
}

export type SaveDraftResult = { ok: true } | { ok: false; errors: string[] };

/** Saves the whole draft. Returns errors instead of redirecting so edits survive. */
export async function saveDraftAction(versionId: string, draft: PricingDraft): Promise<SaveDraftResult> {
  await requireArea('pricing');
  if (!UUID_RE.test(versionId)) return { ok: false, errors: ['Invalid version.'] };

  const issues = validateDraft(draft);
  if (issues.length > 0) {
    return { ok: false, errors: issues.map((i) => `${i.section}: ${i.message}`) };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_save_pricing_draft', {
    p_version_id: versionId,
    p_draft: toSavePayload(draft),
  });
  if (error) return { ok: false, errors: [error.message] };
  revalidatePath('/pricing', 'layout');
  return { ok: true };
}

/** Publishes now, or at `effective_from` (an ISO timestamp) when given. */
export async function publishDraftAction(formData: FormData) {
  await requireArea('pricing');
  const planId = uuidField(formData, 'plan_id', '/pricing');
  const versionId = uuidField(formData, 'version_id', planPath(planId));
  const back = versionPath(planId, versionId);

  const when = field(formData, 'effective_from');
  let effectiveFrom: string | null = null;
  if (when) {
    const at = new Date(when);
    if (Number.isNaN(at.getTime())) go(back, 'error', 'Choose a valid start date and time.');
    effectiveFrom = at.toISOString();
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_publish_pricing_draft', {
    p_version_id: versionId,
    p_effective_from: effectiveFrom,
  });
  if (error) go(back, 'error', error.message);
  revalidatePath('/pricing', 'layout');
  go(
    planPath(planId),
    'ok',
    effectiveFrom ? 'Version scheduled. The current version applies until it starts.' : 'Version published.',
  );
}

/** Deletes an unpublished draft. */
export async function discardDraftAction(formData: FormData) {
  await requireArea('pricing');
  const planId = uuidField(formData, 'plan_id', '/pricing');
  const versionId = uuidField(formData, 'version_id', planPath(planId));
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_discard_pricing_draft', { p_version_id: versionId });
  if (error) go(versionPath(planId, versionId), 'error', error.message);
  revalidatePath(planPath(planId));
  go(planPath(planId), 'ok', 'Draft discarded.');
}

// ---------------------------------------------------------------------------
// Preview
// ---------------------------------------------------------------------------

export type PreviewInput = {
  distance_km: number;
  duration_min: number;
  weight_kg: number;
  volume_m3: number;
  cargo_type_id: string | null;
  equipment_ids: string[];
  zone_id: string | null;
  /** ISO timestamp; time multipliers depend on it. */
  at: string;
};

export type PreviewResult =
  | { ok: true; quote: Record<string, unknown> }
  | { ok: false; error: string };

/** Prices a trip against a saved version (drafts included). */
export async function previewQuoteAction(versionId: string, input: PreviewInput): Promise<PreviewResult> {
  await requireArea('pricing');
  if (!UUID_RE.test(versionId)) return { ok: false, error: 'Invalid version.' };
  const numbers = [input.distance_km, input.duration_min, input.weight_kg, input.volume_m3];
  if (numbers.some((n) => !Number.isFinite(n) || n < 0)) {
    return { ok: false, error: 'Distance, duration, weight and volume must be 0 or more.' };
  }
  const at = new Date(input.at);
  if (Number.isNaN(at.getTime())) return { ok: false, error: 'Choose a valid trip time.' };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc('quote_preview', {
    p_pricing_plan_version_id: versionId,
    p_distance_km: input.distance_km,
    p_duration_min: input.duration_min,
    p_weight_kg: input.weight_kg,
    p_volume_m3: input.volume_m3,
    p_cargo_type_id: input.cargo_type_id || null,
    p_equipment_ids: input.equipment_ids.length ? input.equipment_ids : null,
    p_zone_id: input.zone_id || null,
    p_at_time: at.toISOString(),
  });
  if (error) return { ok: false, error: error.message };
  return { ok: true, quote: (data ?? {}) as Record<string, unknown> };
}
