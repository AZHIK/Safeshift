'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

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
