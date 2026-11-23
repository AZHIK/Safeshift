begin;
do $$
declare
 owner_id uuid;
 agent_id uuid;
 ticket uuid;
 country uuid;
 category uuid;
begin
 select id into strict agent_id from public.profiles where primary_role='admin' limit 1;
 select id into strict owner_id from public.profiles where primary_role='customer' limit 1;
 select id into strict country from public.countries limit 1;
 insert into public.support_categories(code,name) values(gen_random_uuid()::text,'Inbox test') returning id into category;
 insert into public.support_tickets(country_id,ticket_number,opened_by,category_id,subject)
 values(country,gen_random_uuid()::text,owner_id,category,'Inbox test') returning id into ticket;
 insert into public.support_ticket_messages(ticket_id,sender_profile_id,message,is_internal_note) values
 (ticket,owner_id,'Help',false),(ticket,agent_id,'Private note',true);
 if exists(select from public.inbox_messages where ticket_id=ticket) then raise exception 'Unexpected notification'; end if;
 insert into public.support_ticket_messages(ticket_id,sender_profile_id,message) values(ticket,agent_id,'Public reply');
 if (select count(*) from public.inbox_messages where ticket_id=ticket and profile_id=owner_id) <> 1
 or (select status from public.support_tickets where id=ticket) <> 'waiting_customer' then raise exception 'Reply missing'; end if;
 perform set_config('test.inbox_ticket',ticket::text,true);
 perform set_config('request.jwt.claims',json_build_object('sub',agent_id,'role','authenticated')::text,true);
end $$;
set local role authenticated;
do $$begin
 if exists(select from public.inbox_messages where ticket_id=current_setting('test.inbox_ticket')::uuid) then raise exception 'Inbox visible to another user'; end if;
end$$;
rollback;
