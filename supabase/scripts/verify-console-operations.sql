begin;
do $$
declare
 staff uuid; country uuid; city uuid; profile uuid; ticket uuid; category uuid;
 request_id uuid; broadcast uuid:=gen_random_uuid(); delivered integer; result jsonb;
 role_key text:='test_'||replace(gen_random_uuid()::text,'-',''); failed boolean:=false;
begin
 select profile_id into strict staff from public.admin_roles where role_name='super_admin' and is_active and revoked_at is null and (expires_at is null or expires_at>now()) limit 1;
 select id,country_id into strict city,country from public.cities where is_active limit 1;
 select id into strict profile from public.profiles where primary_role='customer' and id<>staff limit 1;
 insert into public.support_categories(code,name) values(gen_random_uuid()::text,'Triage test') returning id into category;
 insert into public.support_tickets(country_id,ticket_number,opened_by,category_id,subject) values(country,gen_random_uuid()::text,profile,category,'Test') returning id into ticket;
 perform set_config('request.jwt.claims',json_build_object('sub',staff,'role','authenticated','aal','aal2')::text,true);
 perform public.admin_create_role_definition(role_key,'District reviewer');
 insert into public.admin_role_permissions(role_name,permission_key) values(role_key,'manage_tickets');
 insert into public.admin_roles(profile_id,role_name,country_id) values(profile,role_key,country);
 perform public.admin_triage_ticket(ticket,'in_progress','high',profile,now()+interval '1 hour');
 if (select assigned_to from public.support_tickets where id=ticket) is distinct from profile then raise exception 'Assignment failed'; end if;
 delivered:=public.admin_announce(broadcast,country,null,'customer','Test only','Test message');
 if public.admin_announce(broadcast,country,null,'customer','Test only','Test message')<>delivered then raise exception 'Broadcast retry changed count'; end if;
 if (select count(*) from public.inbox_messages where title='Test only')<>delivered then raise exception 'Wrong number of deliveries'; end if;
 request_id:=public.admin_open_government_request(country,'Test authority',gen_random_uuid()::text,'Test authority reference',current_date-10,current_date);
 begin perform public.admin_export_government_request(request_id);
 exception when raise_exception then failed:=true; end;
 if not failed then raise exception 'Unapproved disclosure';end if;
 perform public.admin_review_government_request(request_id,'approved','Scope reviewed');
 result:=public.admin_export_government_request(request_id);
 if result is distinct from public.admin_regulator_report(country,current_date-10,current_date) or not (result ? 'recorded_commission') then raise exception 'Approved snapshot incorrect';end if;
 perform set_config('request.jwt.claims',json_build_object('sub',gen_random_uuid(),'role','authenticated','aal','aal2')::text,true);
 begin perform public.admin_export_government_request(request_id);raise exception 'Unauthorized export';exception when insufficient_privilege then null;end;
end $$;
rollback;
