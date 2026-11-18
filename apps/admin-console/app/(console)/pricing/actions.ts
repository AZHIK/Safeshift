'use server';

import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

export async function createPricingPlan(formData: FormData) {
  await requireArea('pricing');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_create_pricing_plan', {
    p_country_id: formData.get('country_id') || null,
    p_city_id: formData.get('city_id'),
    p_vehicle_type_id: formData.get('vehicle_type_id'),
    p_code: formData.get('code'),
    p_name: formData.get('name'),
    p_description: formData.get('description') || null,
    p_currency_code: formData.get('currency_code') || 'TZS',
    p_base_fare: Number(formData.get('base_fare') || 0),
    p_per_km_rate: Number(formData.get('per_km_rate') || 0),
    p_per_min_rate: Number(formData.get('per_min_rate') || 0),
    p_minimum_charge: Number(formData.get('minimum_charge') || 0),
    p_vat_rate: Number(formData.get('vat_rate') || 0.18),
  });
  if (error) throw new Error(error.message);
}

export async function updatePricingPlan(planId: string, formData: FormData) {
  await requireArea('pricing');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_update_pricing_plan', {
    p_plan_id: planId,
    p_name: formData.get('name'),
    p_description: formData.get('description') || null,
    p_is_active: formData.get('is_active') === 'true',
    p_base_fare: Number(formData.get('base_fare') || 0),
    p_per_km_rate: Number(formData.get('per_km_rate') || 0),
    p_per_min_rate: Number(formData.get('per_min_rate') || 0),
    p_minimum_charge: Number(formData.get('minimum_charge') || 0),
    p_vat_rate: Number(formData.get('vat_rate') || 0.18),
  });
  if (error) throw new Error(error.message);
}

export async function deactivatePricingPlan(planId: string) {
  await requireArea('pricing');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_deactivate_pricing_plan', {
    p_plan_id: planId,
  });
  if (error) throw new Error(error.message);
}

export async function deletePricingPlan(planId: string) {
  await requireArea('pricing');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_delete_pricing_plan', {
    p_plan_id: planId,
  });
  if (error) throw new Error(error.message);
}
