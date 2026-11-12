'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { normalizeCode, parseBoolean, parseNumber } from '@/lib/catalog';
import { createClient } from '@/lib/supabase/server';

async function client() {
  return createClient();
}

export async function approveVerificationAction(formData: FormData) {
  const requestId = String(formData.get('request_id') ?? '');
  const notes = String(formData.get('notes') ?? '').trim();
  if (!requestId) return;
  const supabase = await client();
  const { error } = await supabase.rpc('admin_approve_verification', {
    p_request_id: requestId,
    p_notes: notes || null,
  });
  if (error) {
    redirect(`/verifications?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/verifications');
  revalidatePath('/dashboard');
  redirect('/verifications?ok=Verification approved');
}

export async function rejectVerificationAction(formData: FormData) {
  const requestId = String(formData.get('request_id') ?? '');
  const reason = String(formData.get('reason') ?? '').trim();
  if (!requestId || reason.length < 3) {
    redirect('/verifications?error=A rejection reason is required');
  }
  const supabase = await client();
  const { error } = await supabase.rpc('admin_reject_verification', {
    p_request_id: requestId,
    p_reason: reason,
  });
  if (error) {
    redirect(`/verifications?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/verifications');
  revalidatePath('/dashboard');
  redirect('/verifications?ok=Verification rejected');
}

export async function updateTicketAction(formData: FormData) {
  const ticketId = String(formData.get('ticket_id') ?? '');
  const status = String(formData.get('status') ?? '');
  const priority = String(formData.get('priority') ?? '');
  const assignToMe = formData.get('assign_to_me') === 'on';
  if (!ticketId) return;
  const supabase = await client();
  const { data: auth } = await supabase.auth.getUser();
  const update: Record<string, unknown> = {};
  if (status) {
    update.status = status;
    if (status === 'resolved') update.resolved_at = new Date().toISOString();
    if (status === 'closed') {
      update.resolved_at = new Date().toISOString();
      update.closed_at = new Date().toISOString();
    }
  }
  if (priority) update.priority = priority;
  if (assignToMe && auth.user) update.assigned_to = auth.user.id;
  const { error } = await supabase
    .from('support_tickets')
    .update(update)
    .eq('id', ticketId);
  if (error) {
    redirect(`/support/${ticketId}?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath(`/support/${ticketId}`);
  revalidatePath('/support');
  redirect(`/support/${ticketId}?ok=Ticket updated`);
}

export async function replyTicketAction(formData: FormData) {
  const ticketId = String(formData.get('ticket_id') ?? '');
  const message = String(formData.get('message') ?? '').trim();
  if (!ticketId || !message) return;
  const supabase = await client();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) redirect('/login');
  const { error } = await supabase.from('support_ticket_messages').insert({
    ticket_id: ticketId,
    sender_profile_id: auth.user.id,
    message,
    is_internal_note: formData.get('internal') === 'on',
  });
  if (error) {
    redirect(`/support/${ticketId}?error=${encodeURIComponent(error.message)}`);
  }
  await supabase
    .from('support_tickets')
    .update({ status: 'waiting_customer', updated_at: new Date().toISOString() })
    .eq('id', ticketId);
  revalidatePath(`/support/${ticketId}`);
  redirect(`/support/${ticketId}?ok=Reply sent`);
}

export async function updateDisputeAction(formData: FormData) {
  const disputeId = String(formData.get('dispute_id') ?? '');
  const status = String(formData.get('status') ?? '');
  const priority = String(formData.get('priority') ?? '');
  const resolution = String(formData.get('resolution') ?? '').trim();
  if (!disputeId) return;
  const supabase = await client();
  const update: Record<string, unknown> = {};
  if (status) {
    update.status = status;
    if (['resolved_customer', 'resolved_driver', 'resolved_split', 'dismissed'].includes(status)) {
      update.resolved_at = new Date().toISOString();
    }
  }
  if (priority) update.priority = priority;
  if (resolution) update.resolution_notes = resolution;
  const { error } = await supabase
    .from('disputes')
    .update(update)
    .eq('id', disputeId);
  if (error) {
    redirect(`/disputes?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/disputes');
  revalidatePath('/dashboard');
  redirect('/disputes?ok=Dispute updated');
}

export async function resolveIncidentAction(formData: FormData) {
  const incidentId = String(formData.get('incident_id') ?? '');
  const status = String(formData.get('status') ?? 'resolved');
  if (!incidentId) return;
  const supabase = await client();
  const { error } = await supabase
    .from('incidents')
    .update({ status, resolved_at: ['resolved', 'closed'].includes(status) ? new Date().toISOString() : null })
    .eq('id', incidentId);
  if (error) {
    redirect(`/incidents?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/incidents');
  revalidatePath('/dashboard');
  redirect('/incidents?ok=Incident updated');
}

export async function acknowledgeAlertAction(formData: FormData) {
  const alertId = String(formData.get('alert_id') ?? '');
  const status = String(formData.get('status') ?? 'acknowledged');
  if (!alertId) return;
  const supabase = await client();
  const { data: auth } = await supabase.auth.getUser();
  const { error } = await supabase
    .from('trip_alerts')
    .update({
      status,
      acknowledged_by: auth.user?.id ?? null,
      acknowledged_at: new Date().toISOString(),
      resolved_at: status === 'resolved' ? new Date().toISOString() : null,
    })
    .eq('id', alertId);
  if (error) {
    redirect(`/incidents?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/incidents');
  revalidatePath('/dashboard');
  redirect('/incidents?ok=SOS alert updated');
}

export async function updateDataRequestAction(formData: FormData) {
  const requestId = String(formData.get('request_id') ?? '');
  const status = String(formData.get('status') ?? '');
  if (!requestId || !status) return;
  const supabase = await client();
  const { error } = await supabase
    .from('data_subject_requests')
    .update({
      status,
      completed_at: ['completed', 'partially_completed'].includes(status) ? new Date().toISOString() : null,
    })
    .eq('id', requestId);
  if (error) {
    redirect(`/data-requests?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/data-requests');
  redirect('/data-requests?ok=Request updated');
}

export async function toggleFeatureFlagAction(formData: FormData) {
  const flagId = String(formData.get('flag_id') ?? '');
  const enabled = formData.get('enabled') === 'true';
  if (!flagId) return;
  const supabase = await client();
  const { error } = await supabase
    .from('feature_flags')
    .update({ is_enabled: enabled })
    .eq('id', flagId);
  if (error) {
    redirect(`/settings?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/settings');
  redirect('/settings?ok=Feature flag updated');
}


export async function togglePromoAction(formData: FormData) {
  const promoId = String(formData.get('promo_id') ?? '');
  const enabled = formData.get('enabled') === 'true';
  if (!promoId) return;
  const supabase = await client();
  const { error } = await supabase
    .from('promo_codes')
    .update({ is_active: enabled })
    .eq('id', promoId);
  if (error) {
    redirect(`/promos?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath('/promos');
  redirect('/promos?ok=Promo updated');
}

// ----------------------------------------------------------------------------
// Catalogue: vehicle categories and cargo types
//
// The mobile apps read these two catalogues straight from the database, so a
// row that is not here is a row the apps never show. Deactivating is used
// instead of deleting because pricing plans and vehicles reference these ids.
// ----------------------------------------------------------------------------

function catalogError(message: string): never {
  redirect(`/catalog?error=${encodeURIComponent(message)}`);
}

function catalogOk(message: string): never {
  redirect(`/catalog?ok=${encodeURIComponent(message)}`);
}

export async function createVehicleTypeAction(formData: FormData) {
  const code = normalizeCode(String(formData.get('code') ?? ''));
  const name = String(formData.get('name') ?? '').trim();
  const capacityMin = parseNumber(formData.get('capacity_kg_min'));
  const capacityMax = parseNumber(formData.get('capacity_kg_max'));
  const countryId = String(formData.get('country_id') ?? '').trim();

  if (!code) catalogError('A vehicle type code is required.');
  if (!name) catalogError('A vehicle type name is required.');
  if (capacityMin === null || capacityMin <= 0) {
    catalogError('The minimum capacity must be greater than zero.');
  }
  if (capacityMax === null || capacityMax < capacityMin) {
    catalogError('The maximum capacity must not be smaller than the minimum.');
  }

  const supabase = await client();
  const { error } = await supabase
    .from('vehicle_types')
    .insert({
      code,
      name,
      description: String(formData.get('description') ?? '').trim() || null,
      icon_url: String(formData.get('icon_url') ?? '').trim() || null,
      country_id: countryId || null,
      capacity_kg_min: capacityMin,
      capacity_kg_max: capacityMax,
      capacity_m3_min: parseNumber(formData.get('capacity_m3_min')),
      capacity_m3_max: parseNumber(formData.get('capacity_m3_max')),
      number_of_wheels: parseNumber(formData.get('number_of_wheels')),
      requires_special_licence: parseBoolean(formData.get('requires_special_licence')),
      display_order: parseNumber(formData.get('display_order')) ?? 0,
      is_active: true,
    });
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  catalogOk(`${name} added to the vehicle catalogue.`);
}

export async function updateVehicleTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const code = normalizeCode(String(formData.get('code') ?? ''));
  const name = String(formData.get('name') ?? '').trim();
  const capacityMin = parseNumber(formData.get('capacity_kg_min'));
  const capacityMax = parseNumber(formData.get('capacity_kg_max'));
  const countryId = String(formData.get('country_id') ?? '').trim();

  if (!id) catalogError('The vehicle type to update is missing.');
  if (!code) catalogError('A vehicle type code is required.');
  if (!name) catalogError('A vehicle type name is required.');
  if (capacityMin === null || capacityMin <= 0) {
    catalogError('The minimum capacity must be greater than zero.');
  }
  if (capacityMax === null || capacityMax < capacityMin) {
    catalogError('The maximum capacity must not be smaller than the minimum.');
  }

  const supabase = await client();
  const { error } = await supabase
    .from('vehicle_types')
    .update({
      code,
      name,
      description: String(formData.get('description') ?? '').trim() || null,
      icon_url: String(formData.get('icon_url') ?? '').trim() || null,
      country_id: countryId || null,
      capacity_kg_min: capacityMin,
      capacity_kg_max: capacityMax,
      capacity_m3_min: parseNumber(formData.get('capacity_m3_min')),
      capacity_m3_max: parseNumber(formData.get('capacity_m3_max')),
      number_of_wheels: parseNumber(formData.get('number_of_wheels')),
      requires_special_licence: parseBoolean(formData.get('requires_special_licence')),
      display_order: parseNumber(formData.get('display_order')) ?? 0,
    })
    .eq('id', id);
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  revalidatePath(`/catalog/vehicle-types/${id}`);
  catalogOk(`${name} updated.`);
}

export async function toggleVehicleTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const active = formData.get('active') === 'true';
  if (!id) return;
  const supabase = await client();
  const { error } = await supabase
    .from('vehicle_types')
    .update({ is_active: active })
    .eq('id', id);
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  catalogOk(active ? 'Vehicle type activated.' : 'Vehicle type deactivated.');
}

// Deleting is offered for rows nothing references yet. Once a vehicle, a
// pricing plan or a quote points at a catalogue row, the database refuses the
// delete and the operator deactivates the row instead.
export async function deleteVehicleTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const supabase = await client();
  const { error } = await supabase
    .from('vehicle_types')
    .delete()
    .eq('id', id);
  if (error) {
    catalogError(
      `This vehicle type is referenced by existing data, so it cannot be deleted. ` +
        `Deactivate it instead. (${error.message})`,
    );
  }

  revalidatePath('/catalog');
  catalogOk('Vehicle type deleted.');
}

export async function createCargoTypeAction(formData: FormData) {
  const code = normalizeCode(String(formData.get('code') ?? ''));
  const name = String(formData.get('name') ?? '').trim();
  const countryId = String(formData.get('country_id') ?? '').trim();
  const categoryId = String(formData.get('category_id') ?? '').trim();

  if (!code) catalogError('A cargo type code is required.');
  if (!name) catalogError('A cargo type name is required.');

  const allowed = formData.getAll('allowed_vehicle_type_codes').map((value) => String(value));
  const prohibited = formData
    .getAll('prohibited_vehicle_type_codes')
    .map((value) => String(value));

  const supabase = await client();
  const { error } = await supabase
    .from('cargo_types')
    .insert({
      code,
      name,
      description: String(formData.get('description') ?? '').trim() || null,
      icon_url: String(formData.get('icon_url') ?? '').trim() || null,
      country_id: countryId || null,
      category_id: categoryId || null,
      requires_special_handling: parseBoolean(formData.get('requires_special_handling')),
      requires_declared_value: parseBoolean(formData.get('requires_declared_value')),
      requires_insurance: parseBoolean(formData.get('requires_insurance')),
      allowed_vehicle_type_codes: allowed,
      prohibited_vehicle_type_codes: prohibited,
      max_value_tzs: parseNumber(formData.get('max_value_tzs')),
      display_order: parseNumber(formData.get('display_order')) ?? 0,
      is_active: true,
    });
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  catalogOk(`${name} added to the cargo catalogue.`);
}

export async function updateCargoTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const code = normalizeCode(String(formData.get('code') ?? ''));
  const name = String(formData.get('name') ?? '').trim();
  const countryId = String(formData.get('country_id') ?? '').trim();
  const categoryId = String(formData.get('category_id') ?? '').trim();

  if (!id) catalogError('The cargo type to update is missing.');
  if (!code) catalogError('A cargo type code is required.');
  if (!name) catalogError('A cargo type name is required.');

  const allowed = formData.getAll('allowed_vehicle_type_codes').map((value) => String(value));
  const prohibited = formData
    .getAll('prohibited_vehicle_type_codes')
    .map((value) => String(value));

  const supabase = await client();
  const { error } = await supabase
    .from('cargo_types')
    .update({
      code,
      name,
      description: String(formData.get('description') ?? '').trim() || null,
      icon_url: String(formData.get('icon_url') ?? '').trim() || null,
      country_id: countryId || null,
      category_id: categoryId || null,
      requires_special_handling: parseBoolean(formData.get('requires_special_handling')),
      requires_declared_value: parseBoolean(formData.get('requires_declared_value')),
      requires_insurance: parseBoolean(formData.get('requires_insurance')),
      allowed_vehicle_type_codes: allowed,
      prohibited_vehicle_type_codes: prohibited,
      max_value_tzs: parseNumber(formData.get('max_value_tzs')),
      display_order: parseNumber(formData.get('display_order')) ?? 0,
    })
    .eq('id', id);
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  revalidatePath(`/catalog/cargo-types/${id}`);
  catalogOk(`${name} updated.`);
}

export async function toggleCargoTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  const active = formData.get('active') === 'true';
  if (!id) return;
  const supabase = await client();
  const { error } = await supabase
    .from('cargo_types')
    .update({ is_active: active })
    .eq('id', id);
  if (error) catalogError(error.message);

  revalidatePath('/catalog');
  catalogOk(active ? 'Cargo type activated.' : 'Cargo type deactivated.');
}

export async function deleteCargoTypeAction(formData: FormData) {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const supabase = await client();
  const { error } = await supabase
    .from('cargo_types')
    .delete()
    .eq('id', id);
  if (error) {
    catalogError(
      `This cargo type is referenced by existing data, so it cannot be deleted. ` +
        `Deactivate it instead. (${error.message})`,
    );
  }

  revalidatePath('/catalog');
  catalogOk('Cargo type deleted.');
}
