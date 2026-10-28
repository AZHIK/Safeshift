-- ============================================================================
-- 0100 — Phase 6: chat messages and attachments
-- ============================================================================
-- chat_messages is monthly partitioned (12 months). Because PostgreSQL cannot
-- reference a partitioned table by id alone, reply and attachment integrity are
-- enforced by trigger functions. These functions are deliberately stricter than
-- a nullable text reference and validate that the target message exists in the
-- same thread.
-- ============================================================================

create table public.chat_messages (
  id bigint generated always as identity,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_profile_id uuid not null references public.profiles(id) on delete cascade,
  message_type text not null default 'text',
  body text,
  metadata jsonb not null default '{}',
  reply_to_message_id bigint,
  is_edited boolean not null default false,
  edited_at timestamptz,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (id, created_at),
  constraint chat_messages_type_check
    check (message_type in ('text', 'image', 'location', 'system')),
  constraint chat_messages_text_body_check
    check (message_type <> 'text' or (body is not null and length(btrim(body)) > 0)),
  constraint chat_messages_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  constraint chat_messages_edited_pair_check
    check (is_edited = false or edited_at is not null),
  constraint chat_messages_deleted_pair_check
    check (is_deleted = false or deleted_at is not null)
) partition by range (created_at);

comment on table public.chat_messages is
  'Append-only chat messages, partitioned monthly. Soft deletion uses is_deleted; physical DELETE is blocked.';

create table public.chat_messages_default
  partition of public.chat_messages default;
revoke all on table public.chat_messages_default from anon, authenticated;

select private.ensure_monthly_partitions('public', 'chat_messages', 'created_at', 12);

create table public.chat_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id bigint not null,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  storage_path text not null,
  file_mime_type text,
  file_size_bytes bigint,
  created_at timestamptz not null default now(),
  constraint chat_attachments_message_positive_check check (message_id > 0),
  constraint chat_attachments_storage_path_not_blank_check check (length(btrim(storage_path)) > 0),
  constraint chat_attachments_file_size_check check (file_size_bytes is null or file_size_bytes >= 0)
);

comment on column public.chat_attachments.message_id is
  'References chat_messages.id across partitions. Integrity is enforced by private.validate_chat_attachment() because a partitioned table cannot be referenced by id alone.';

-- ----------------------------------------------------------------------------
-- Integrity triggers
-- ----------------------------------------------------------------------------
create or replace function private.validate_chat_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reply_to_message_id is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.chat_messages m
     where m.id = new.reply_to_message_id
       and m.thread_id = new.thread_id
  ) then
    raise exception 'reply_to_message_id % does not exist in thread %',
      new.reply_to_message_id, new.thread_id
      using errcode = '23503';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_chat_reply() from public;
revoke all on function private.validate_chat_reply() from anon;
revoke all on function private.validate_chat_reply() from authenticated;
grant execute on function private.validate_chat_reply() to service_role;

create trigger trg_chat_messages_validate_reply
  before insert or update of reply_to_message_id, thread_id on public.chat_messages
  for each row execute function private.validate_chat_reply();

create or replace function private.validate_chat_attachment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
      from public.chat_messages m
     where m.id = new.message_id
       and m.thread_id = new.thread_id
  ) then
    raise exception 'attachment message_id % does not exist in thread %',
      new.message_id, new.thread_id
      using errcode = '23503';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_chat_attachment() from public;
revoke all on function private.validate_chat_attachment() from anon;
revoke all on function private.validate_chat_attachment() from authenticated;
grant execute on function private.validate_chat_attachment() to service_role;

create trigger trg_chat_attachments_validate_message
  before insert or update of message_id, thread_id on public.chat_attachments
  for each row execute function private.validate_chat_attachment();

-- Keep the thread summary current without allowing clients to write chat_threads.
create or replace function private.sync_chat_thread_last_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preview text;
begin
  if new.is_deleted then
    return new;
  end if;

  v_preview := case
    when new.message_type = 'image' then '[image]'
    when new.message_type = 'location' then '[location]'
    when new.message_type = 'system' then coalesce(new.body, '[system]')
    else new.body
  end;

  update public.chat_threads
     set last_message_at = new.created_at,
         last_message_preview = left(v_preview, 240)
   where id = new.thread_id;

  return new;
end;
$$;

revoke all on function private.sync_chat_thread_last_message() from public;
revoke all on function private.sync_chat_thread_last_message() from anon;
revoke all on function private.sync_chat_thread_last_message() from authenticated;
grant execute on function private.sync_chat_thread_last_message() to service_role;

create trigger trg_chat_messages_sync_thread
  after insert on public.chat_messages
  for each row execute function private.sync_chat_thread_last_message();
