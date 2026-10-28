-- ============================================================================
-- 0105 — Phase 6: support categories, tickets, ticket messages
-- ============================================================================
-- Support tickets are a separate domain from Phase 4 disputes. A ticket may
-- reference a job or a dispute without becoming either.
-- ============================================================================

create table public.support_categories (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references public.countries(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_categories_code_not_blank_check check (length(btrim(code)) > 0),
  constraint support_categories_name_not_blank_check check (length(btrim(name)) > 0),
  constraint support_categories_display_order_check check (display_order >= 0),
  constraint support_categories_scope_key
    unique nulls not distinct (country_id, code)
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete restrict,
  ticket_number text not null unique,
  opened_by uuid not null references public.profiles(id) on delete restrict,
  assigned_to uuid references public.profiles(id) on delete set null,
  category_id uuid not null references public.support_categories(id) on delete restrict,
  subject text not null,
  status text not null default 'open',
  priority text not null default 'normal',
  related_job_id uuid references public.jobs(id) on delete set null,
  related_dispute_id uuid references public.disputes(id) on delete set null,
  sla_due_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  satisfaction_rating smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_tickets_ticket_number_not_blank_check check (length(btrim(ticket_number)) > 0),
  constraint support_tickets_subject_not_blank_check check (length(btrim(subject)) > 0),
  constraint support_tickets_status_check
    check (status in ('open', 'in_progress', 'waiting_customer', 'resolved', 'closed')),
  constraint support_tickets_priority_check
    check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint support_tickets_satisfaction_check
    check (satisfaction_rating is null or satisfaction_rating between 1 and 5),
  constraint support_tickets_resolved_at_check
    check (status not in ('resolved', 'closed') or resolved_at is not null),
  constraint support_tickets_closed_at_check
    check (status <> 'closed' or closed_at is not null)
);

create index idx_support_tickets_ticket_number on public.support_tickets (ticket_number);

create trigger trg_support_categories_updated_at
  before update on public.support_categories
  for each row execute function public.set_updated_at();

create trigger trg_support_tickets_updated_at
  before update on public.support_tickets
  for each row execute function public.set_updated_at();

create table public.support_ticket_messages (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_profile_id uuid not null references public.profiles(id) on delete restrict,
  message text not null,
  is_internal_note boolean not null default false,
  attachments text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint support_ticket_messages_message_not_blank_check check (length(btrim(message)) > 0),
  constraint support_ticket_messages_attachments_no_nulls_check
    check (array_position(attachments, null) is null)
);

comment on table public.support_ticket_messages is
  'Append-only ticket conversation. Internal notes are filtered by RLS for non-staff readers.';
