-- ============================================================================
-- SafeShift — Phase 2 / Migration 0032
-- Scheduled document-expiry notifications. Delivery is handled later.
-- ============================================================================

create table public.document_expiry_reminders (
  id uuid primary key default gen_random_uuid(),
  driver_document_id uuid references public.driver_documents (id) on delete cascade,
  vehicle_document_id uuid references public.vehicle_documents (id) on delete cascade,
  reminder_type text not null,
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  delivery_channel text,
  delivery_status text,
  created_at timestamptz not null default now(),
  constraint document_expiry_reminders_document_check check ((driver_document_id is not null)::integer + (vehicle_document_id is not null)::integer = 1),
  constraint document_expiry_reminders_type_check check (reminder_type in ('30_days', '14_days', '7_days', '1_day', 'expired')),
  constraint document_expiry_reminders_channel_check check (delivery_channel is null or delivery_channel in ('push', 'sms', 'email')),
  constraint document_expiry_reminders_status_check check (delivery_status is null or delivery_status in ('pending', 'sent', 'failed', 'bounced'))
);

