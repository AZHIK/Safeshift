-- ============================================================================
-- 0112 — Phase 6: immutability and write-path triggers
-- ============================================================================

-- current_user is the function owner when a SECURITY DEFINER maintenance
-- function runs. auth.role() remains the JWT role, so testing only auth.role()
-- would incorrectly block a legitimate staff-triggered analytics refresh.
-- This helper lives in public because trigger functions run as the invoking
-- role and authenticated has no USAGE on the private schema.
create or replace function public.is_privileged_writer()
returns boolean
language sql
stable
set search_path = ''
as $$
  select current_user in ('postgres', 'supabase_admin', 'service_role')
      or coalesce(auth.role(), '') = 'service_role'
      or (
        session_user in ('postgres', 'supabase_admin')
        and coalesce(auth.role(), '') in ('', 'service_role')
      );
$$;

comment on function public.is_privileged_writer() is
  'True for service/owner maintenance paths; false for direct authenticated client writes.';

revoke all on function public.is_privileged_writer() from public;
revoke all on function public.is_privileged_writer() from anon;
grant execute on function public.is_privileged_writer() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- notification_log
-- ----------------------------------------------------------------------------
create or replace function private.enforce_notification_log_immutability()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_new_core jsonb;
  v_old_core jsonb;
begin
  if public.is_privileged_writer() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'notification_log is append-only; rows cannot be deleted'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array[
    'status', 'sent_at', 'delivered_at', 'read_at',
    'failure_reason', 'provider_response', 'provider_message_id'
  ];
  v_old_core := to_jsonb(old) - array[
    'status', 'sent_at', 'delivered_at', 'read_at',
    'failure_reason', 'provider_response', 'provider_message_id'
  ];

  if v_new_core is distinct from v_old_core then
    raise exception 'notification_log identity and content are immutable'
      using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    if not (
      (old.status = 'pending' and new.status in ('sent', 'failed'))
      or (old.status = 'sent' and new.status in ('delivered', 'failed', 'read'))
      or (old.status = 'delivered' and new.status = 'read')
      or (old.status = 'failed' and new.status in ('pending', 'sent'))
    ) then
      raise exception 'invalid notification_log status transition from % to %',
        old.status, new.status
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_notification_log_immutable
  before update or delete on public.notification_log
  for each row execute function private.enforce_notification_log_immutability();

-- ----------------------------------------------------------------------------
-- chat_messages
-- ----------------------------------------------------------------------------
create or replace function private.enforce_chat_message_immutability()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_new_core jsonb;
  v_old_core jsonb;
begin
  if public.is_privileged_writer() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'chat messages are soft-deleted; physical delete is blocked'
      using errcode = '42501';
  end if;

  if new.thread_id is distinct from old.thread_id
     or new.sender_profile_id is distinct from old.sender_profile_id
     or new.message_type is distinct from old.message_type
     or new.reply_to_message_id is distinct from old.reply_to_message_id
     or new.created_at is distinct from old.created_at then
    raise exception 'chat message identity is immutable'
      using errcode = '42501';
  end if;

  if auth.uid() is distinct from old.sender_profile_id then
    raise exception 'only the sender can edit or soft-delete a chat message'
      using errcode = '42501';
  end if;

  if old.is_deleted then
    raise exception 'deleted chat messages cannot be edited'
      using errcode = '42501';
  end if;

  if new.is_deleted and not old.is_deleted then
    if new.deleted_at is null then
      raise exception 'deleted_at is required when soft-deleting a message'
        using errcode = '23514';
    end if;
    return new;
  end if;

  if old.is_deleted is distinct from new.is_deleted
     or old.deleted_at is distinct from new.deleted_at then
    raise exception 'chat message deletion flags can only move from false to true'
      using errcode = '42501';
  end if;

  if old.created_at < now() - interval '5 minutes' then
    raise exception 'chat messages can only be edited within five minutes'
      using errcode = '42501';
  end if;

  v_new_core := to_jsonb(new) - array['body', 'metadata', 'is_edited', 'edited_at'];
  v_old_core := to_jsonb(old) - array['body', 'metadata', 'is_edited', 'edited_at'];

  if v_new_core is distinct from v_old_core then
    raise exception 'chat message fields other than body/metadata are immutable'
      using errcode = '42501';
  end if;

  if new.body is distinct from old.body or new.metadata is distinct from old.metadata then
    new.is_edited := true;
    new.edited_at := now();
  end if;

  return new;
end;
$$;

create trigger trg_chat_messages_immutable
  before update or delete on public.chat_messages
  for each row execute function private.enforce_chat_message_immutability();

-- ----------------------------------------------------------------------------
-- Append-only action and log tables
-- ----------------------------------------------------------------------------
create or replace function private.enforce_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_privileged_writer() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  raise exception '% is append-only; % is blocked', tg_table_name, tg_op
    using errcode = '42501';
end;
$$;

create trigger trg_incident_actions_immutable
  before update or delete on public.incident_actions
  for each row execute function private.enforce_append_only();

create trigger trg_support_ticket_messages_immutable
  before update or delete on public.support_ticket_messages
  for each row execute function private.enforce_append_only();

create trigger trg_data_access_log_immutable
  before update or delete on public.data_access_log
  for each row execute function private.enforce_append_only();

-- ----------------------------------------------------------------------------
-- Analytics tables: client writes are blocked; maintenance functions upsert.
-- ----------------------------------------------------------------------------
create or replace function private.enforce_metrics_writer()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_privileged_writer() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  raise exception '% is written only by analytics maintenance functions', tg_table_name
    using errcode = '42501';
end;
$$;

create trigger trg_daily_metrics_writer
  before update or delete on public.daily_metrics
  for each row execute function private.enforce_metrics_writer();

create trigger trg_zone_metrics_writer
  before update or delete on public.zone_metrics
  for each row execute function private.enforce_metrics_writer();

create trigger trg_driver_metrics_writer
  before update or delete on public.driver_metrics
  for each row execute function private.enforce_metrics_writer();

create trigger trg_customer_metrics_writer
  before update or delete on public.customer_metrics
  for each row execute function private.enforce_metrics_writer();

create trigger trg_demand_snapshots_writer
  before update or delete on public.demand_snapshots
  for each row execute function private.enforce_metrics_writer();

-- The private helper is retired; trigger functions must be invoker-safe.
drop function if exists private.is_privileged_writer();

-- ----------------------------------------------------------------------------
-- Audit trails on mutable communication/safety/support/compliance roots.
-- Append-only logs and high-volume telemetry/analytics rows are intentionally
-- not audited row-by-row; their own tables are the audit/reporting record.
-- ----------------------------------------------------------------------------
do $$
declare
  v_table text;
  v_tables text[] := array[
    'public.push_tokens',
    'public.notification_templates',
    'public.notification_preferences',
    'public.chat_threads',
    'public.emergency_contacts',
    'public.incidents',
    'public.blocked_users',
    'public.prohibited_items',
    'public.support_categories',
    'public.support_tickets',
    'public.retention_policies',
    'public.data_subject_requests'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists %I on %s',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
    execute format(
      'create trigger %I after insert or update or delete on %s for each row execute function private.audit_trigger()',
      'trg_' || replace(v_table, 'public.', '') || '_audit',
      v_table
    );
  end loop;
end $$;
