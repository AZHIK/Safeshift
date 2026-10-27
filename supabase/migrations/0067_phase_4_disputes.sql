-- ============================================================================
-- SafeShift — Phase 4 / Migration 0067
-- Dispute workflow header.
--
-- Messages, attachments and the immutable resolution log are separate tables.
-- SLA tracking is explicit so support can sort by breach risk.
-- ============================================================================

create table public.disputes (
  id                   uuid primary key default gen_random_uuid(),
  job_id               uuid not null references public.jobs (id) on delete restrict,
  raised_by            uuid not null references public.profiles (id) on delete restrict,
  raised_by_role       public.user_role not null,
  dispute_type         text not null,
  status               text not null default 'open',
  priority             text not null default 'normal',
  summary              text not null,
  requested_resolution text,
  resolved_by          uuid references public.profiles (id) on delete set null,
  resolved_at          timestamptz,
  resolution_notes     text,
  compensation_amount  numeric(14,2),
  currency_code        char(3) references public.currencies (code) on update cascade on delete restrict,
  sla_due_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint disputes_type_check check (
    dispute_type in ('damage', 'loss', 'delay', 'rude_behavior', 'fare_dispute', 'no_show', 'safety', 'other')
  ),
  constraint disputes_status_check check (
    status in (
      'open',
      'in_review',
      'resolved_customer',
      'resolved_driver',
      'resolved_split',
      'dismissed',
      'escalated'
    )
  ),
  constraint disputes_priority_check check (
    priority in ('low', 'normal', 'high', 'urgent')
  ),
  constraint disputes_role_check check (
    raised_by_role in ('customer', 'driver', 'admin')
  ),
  constraint disputes_summary_check check (length(btrim(summary)) > 0),
  constraint disputes_compensation_check check (compensation_amount is null or compensation_amount >= 0),
  constraint disputes_compensation_currency_check check (
    compensation_amount is null or currency_code is not null
  )
);

comment on table public.disputes is
  'Dispute header and workflow state. Job/customer/driver visibility is derived from job participation; support sees everything with manage_disputes.';

comment on column public.disputes.sla_due_at is
  'Operational response deadline. The dispute queue view highlights overdue open/in-review/escalated disputes.';
