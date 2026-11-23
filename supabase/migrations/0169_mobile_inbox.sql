-- Persistent in-app delivery. Clients can read and acknowledge only their own messages.
create table public.inbox_messages (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  title text not null,
  body text not null,
  ticket_id uuid references public.support_tickets on delete cascade,
  reply_id bigint unique references public.support_ticket_messages on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index inbox_profile_date on public.inbox_messages(profile_id, created_at desc);
alter table public.inbox_messages enable row level security;
revoke all on public.inbox_messages from anon, authenticated, public;
grant select, update(read_at) on public.inbox_messages to authenticated;
create policy inbox_select on public.inbox_messages for select to authenticated using (profile_id = (select auth.uid()));
create policy inbox_acknowledge on public.inbox_messages for update to authenticated using (profile_id = (select auth.uid())) with check (profile_id = (select auth.uid()));
alter publication supabase_realtime add table public.inbox_messages;

create function private.notify_ticket_opener() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  ticket public.support_tickets%rowtype;
begin
  select * into strict ticket from public.support_tickets where id = new.ticket_id for update;
  if new.sender_profile_id <> ticket.opened_by and not new.is_internal_note then
    insert into public.inbox_messages(profile_id,title,body,ticket_id,reply_id)
    values (ticket.opened_by, 'Support replied', ticket.ticket_number || ' · ' || ticket.subject, ticket.id, new.id);
    update public.support_tickets set status = 'waiting_customer'
      where id = ticket.id and status not in ('closed','resolved');
  end if;
  return new;
end;
$$;
revoke all on function private.notify_ticket_opener() from public, anon, authenticated;
create trigger notify_ticket_opener after insert on public.support_ticket_messages
for each row when (not new.is_internal_note) execute function private.notify_ticket_opener();
