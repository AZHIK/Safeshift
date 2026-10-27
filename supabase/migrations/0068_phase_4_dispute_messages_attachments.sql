-- ============================================================================
-- SafeShift — Phase 4 / Migration 0068
-- Dispute conversation, attachments and immutable resolution events.
-- ============================================================================

create table public.dispute_messages (
  id                uuid primary key default gen_random_uuid(),
  dispute_id        uuid not null references public.disputes (id) on delete cascade,
  sender_profile_id uuid not null references public.profiles (id) on delete restrict,
  message           text not null,
  is_internal_note  boolean not null default false,
  created_at        timestamptz not null default now(),

  constraint dispute_messages_message_check check (length(btrim(message)) > 0)
);

comment on table public.dispute_messages is
  'Conversation entries. is_internal_note rows are visible only to staff with manage_disputes.';

create table public.dispute_attachments (
  id              uuid primary key default gen_random_uuid(),
  dispute_id      uuid not null references public.disputes (id) on delete cascade,
  message_id      uuid references public.dispute_messages (id) on delete cascade,
  uploaded_by     uuid not null references public.profiles (id) on delete restrict,
  storage_path    text not null,
  file_mime_type  text,
  file_size_bytes bigint,
  created_at      timestamptz not null default now(),

  constraint dispute_attachments_path_check check (length(btrim(storage_path)) > 0),
  constraint dispute_attachments_size_check check (file_size_bytes is null or file_size_bytes >= 0)
);

comment on table public.dispute_attachments is
  'Object-storage references for dispute evidence. A trigger ensures an attached message belongs to the same dispute.';

create table public.dispute_resolutions (
  id           bigint generated always as identity primary key,
  dispute_id   uuid not null references public.disputes (id) on delete cascade,
  resolver_id  uuid not null references public.profiles (id) on delete restrict,
  action       text not null,
  from_state   text,
  to_state     text,
  details      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),

  constraint dispute_resolutions_action_check check (
    action in ('assigned', 'status_changed', 'compensation_granted', 'escalated', 'closed')
  ),
  constraint dispute_resolutions_details_object_check check (jsonb_typeof(details) = 'object')
);

comment on table public.dispute_resolutions is
  'Append-only audit of every dispute assignment, status change, compensation grant, escalation and close. UPDATE and DELETE are blocked.';
