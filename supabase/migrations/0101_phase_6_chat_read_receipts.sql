-- ============================================================================
-- 0101 — Phase 6: chat read receipts
-- ============================================================================

create table public.chat_read_receipts (
  id bigint generated always as identity primary key,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  last_read_message_id bigint,
  last_read_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint chat_read_receipts_message_positive_check
    check (last_read_message_id is null or last_read_message_id > 0),
  constraint chat_read_receipts_thread_profile_key unique (thread_id, profile_id)
);

create or replace function private.validate_chat_read_receipt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.last_read_message_id is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.chat_messages m
     where m.id = new.last_read_message_id
       and m.thread_id = new.thread_id
  ) then
    raise exception 'last_read_message_id % does not exist in thread %',
      new.last_read_message_id, new.thread_id
      using errcode = '23503';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_chat_read_receipt() from public;
revoke all on function private.validate_chat_read_receipt() from anon;
revoke all on function private.validate_chat_read_receipt() from authenticated;
grant execute on function private.validate_chat_read_receipt() to service_role;

create trigger trg_chat_read_receipts_validate_message
  before insert or update of last_read_message_id, thread_id on public.chat_read_receipts
  for each row execute function private.validate_chat_read_receipt();
