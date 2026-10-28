-- ============================================================================
-- 0114 — Phase 6: permissions, helper functions, RLS, and grants
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Participant / read helpers
-- ----------------------------------------------------------------------------
create or replace function private.is_job_participant(p_job_id uuid, p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.jobs j
     where j.id = p_job_id
       and (j.customer_id = p_profile_id or j.driver_id = p_profile_id)
  );
$$;

create or replace function private.can_read_incident(p_incident_id uuid, p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.incidents i
     where i.id = p_incident_id
       and (
         i.reported_by = p_profile_id
         or (i.job_id is not null and private.is_job_participant(i.job_id, p_profile_id))
         or (p_profile_id = auth.uid() and public.has_permission('view_incidents'))
       )
  );
$$;

create or replace function private.can_read_support_ticket(p_ticket_id uuid, p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.support_tickets t
     where t.id = p_ticket_id
       and (
         t.opened_by = p_profile_id
         or t.assigned_to = p_profile_id
         or (p_profile_id = auth.uid() and public.has_permission('view_all_tickets'))
       )
  );
$$;

revoke all on function private.is_job_participant(uuid, uuid) from public;
revoke all on function private.can_read_incident(uuid, uuid) from public;
revoke all on function private.can_read_support_ticket(uuid, uuid) from public;
grant execute on function private.is_job_participant(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_read_incident(uuid, uuid) to authenticated, service_role;
grant execute on function private.can_read_support_ticket(uuid, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Permission catalogue
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_notifications',      'Manage notification templates and send configuration', 'communication'),
  ('view_incidents',            'View safety incidents',                               'safety'),
  ('manage_incidents',          'Assign, update, and resolve safety incidents',        'safety'),
  ('manage_prohibited_items',   'Manage jurisdiction prohibited-item catalogues',      'safety'),
  ('manage_support',            'Manage support categories and support configuration', 'support'),
  ('view_all_tickets',          'View every support ticket and internal note',         'support'),
  ('manage_tickets',            'Assign and update support tickets',                   'support'),
  ('view_data_access',          'View PDPC data access logs',                          'compliance'),
  ('view_retention',            'View data retention policies',                        'compliance'),
  ('manage_retention',          'Manage and execute data retention policies',          'compliance'),
  ('manage_data_requests',      'Process GDPR/PDPC data subject requests',             'compliance'),
  ('view_analytics',            'View batch analytics and operational dashboards',     'analytics'),
  ('manage_analytics',          'Run analytics batch functions',                       'analytics')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select v.role_name, v.permission_key
  from (values
    ('super_admin',        'manage_notifications'),
    ('super_admin',        'view_incidents'),
    ('super_admin',        'manage_incidents'),
    ('super_admin',        'manage_prohibited_items'),
    ('super_admin',        'manage_support'),
    ('super_admin',        'view_all_tickets'),
    ('super_admin',        'manage_tickets'),
    ('super_admin',        'view_data_access'),
    ('super_admin',        'view_retention'),
    ('super_admin',        'manage_retention'),
    ('super_admin',        'manage_data_requests'),
    ('super_admin',        'view_analytics'),
    ('super_admin',        'manage_analytics'),
    ('operations_admin',   'manage_notifications'),
    ('operations_admin',   'view_incidents'),
    ('operations_admin',   'manage_incidents'),
    ('operations_admin',   'manage_prohibited_items'),
    ('operations_admin',   'view_all_tickets'),
    ('operations_admin',   'manage_tickets'),
    ('operations_admin',   'view_analytics'),
    ('verification_admin', 'view_incidents'),
    ('verification_admin', 'view_analytics'),
    ('support_agent',      'view_incidents'),
    ('support_agent',      'view_all_tickets'),
    ('support_agent',      'manage_tickets'),
    ('support_agent',      'manage_support'),
    ('support_agent',      'manage_data_requests'),
    ('finance_admin',      'view_analytics'),
    ('analyst',            'view_analytics'),
    ('analyst',            'view_data_access'),
    ('analyst',            'view_retention')
  ) as v(role_name, permission_key)
 where not exists (
   select 1
     from public.admin_role_permissions existing
    where existing.role_name = v.role_name
      and existing.permission_key = v.permission_key
 );

-- ----------------------------------------------------------------------------
-- 3. Enable RLS
-- ----------------------------------------------------------------------------
alter table public.push_tokens enable row level security;
alter table public.notification_templates enable row level security;
alter table public.notification_log enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_attachments enable row level security;
alter table public.chat_read_receipts enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_actions enable row level security;
alter table public.blocked_users enable row level security;
alter table public.prohibited_items enable row level security;
alter table public.support_categories enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
alter table public.data_access_log enable row level security;
alter table public.retention_policies enable row level security;
alter table public.data_subject_requests enable row level security;
alter table public.daily_metrics enable row level security;
alter table public.zone_metrics enable row level security;
alter table public.driver_metrics enable row level security;
alter table public.customer_metrics enable row level security;
alter table public.demand_snapshots enable row level security;

-- ----------------------------------------------------------------------------
-- 4. Policies
-- ----------------------------------------------------------------------------
-- push_tokens
create policy push_tokens_select_own on public.push_tokens
  for select to authenticated
  using (profile_id = (select auth.uid()));
create policy push_tokens_insert_own on public.push_tokens
  for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy push_tokens_update_own on public.push_tokens
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated
  using (profile_id = (select auth.uid()));

-- notification_templates
create policy notification_templates_select_authenticated on public.notification_templates
  for select to authenticated using (true);
create policy notification_templates_insert_manage on public.notification_templates
  for insert to authenticated
  with check ((select public.has_permission('manage_notifications')));
create policy notification_templates_update_manage on public.notification_templates
  for update to authenticated
  using ((select public.has_permission('manage_notifications')))
  with check ((select public.has_permission('manage_notifications')));
create policy notification_templates_delete_manage on public.notification_templates
  for delete to authenticated
  using ((select public.has_permission('manage_notifications')));

-- notification_log
create policy notification_log_select_own on public.notification_log
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- notification_preferences
create policy notification_preferences_select_own on public.notification_preferences
  for select to authenticated
  using (profile_id = (select auth.uid()));
create policy notification_preferences_insert_own on public.notification_preferences
  for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy notification_preferences_update_own on public.notification_preferences
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy notification_preferences_delete_own on public.notification_preferences
  for delete to authenticated
  using (profile_id = (select auth.uid()));

-- chat_threads
create policy chat_threads_select_participant on public.chat_threads
  for select to authenticated
  using (private.is_job_participant(job_id, (select auth.uid())));

-- chat_messages
create policy chat_messages_select_participant on public.chat_messages
  for select to authenticated
  using (
    exists (
      select 1
        from public.chat_threads t
       where t.id = chat_messages.thread_id
         and t.status in ('active', 'read_only', 'archived')
         and private.is_job_participant(t.job_id, (select auth.uid()))
    )
  );
create policy chat_messages_insert_participant on public.chat_messages
  for insert to authenticated
  with check (
    sender_profile_id = (select auth.uid())
    and exists (
      select 1
        from public.chat_threads t
       where t.id = chat_messages.thread_id
         and t.status = 'active'
         and private.is_job_participant(t.job_id, (select auth.uid()))
    )
  );
create policy chat_messages_update_own on public.chat_messages
  for update to authenticated
  using (
    sender_profile_id = (select auth.uid())
    and not is_deleted
    and exists (
      select 1
        from public.chat_threads t
       where t.id = chat_messages.thread_id
         and t.status = 'active'
    )
  )
  with check (
    sender_profile_id = (select auth.uid())
    and exists (
      select 1
        from public.chat_threads t
       where t.id = chat_messages.thread_id
         and t.status = 'active'
    )
  );

-- chat_attachments
create policy chat_attachments_select_participant on public.chat_attachments
  for select to authenticated
  using (
    exists (
      select 1
        from public.chat_threads t
       where t.id = chat_attachments.thread_id
         and private.is_job_participant(t.job_id, (select auth.uid()))
    )
  );
create policy chat_attachments_insert_participant on public.chat_attachments
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.chat_threads t
       where t.id = chat_attachments.thread_id
         and t.status = 'active'
         and private.is_job_participant(t.job_id, (select auth.uid()))
    )
  );

-- chat_read_receipts
create policy chat_read_receipts_select_own on public.chat_read_receipts
  for select to authenticated
  using (profile_id = (select auth.uid()));
create policy chat_read_receipts_insert_own on public.chat_read_receipts
  for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy chat_read_receipts_update_own on public.chat_read_receipts
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy chat_read_receipts_delete_own on public.chat_read_receipts
  for delete to authenticated
  using (profile_id = (select auth.uid()));

-- emergency_contacts
create policy emergency_contacts_select_own on public.emergency_contacts
  for select to authenticated
  using (profile_id = (select auth.uid()));
create policy emergency_contacts_insert_own on public.emergency_contacts
  for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy emergency_contacts_update_own on public.emergency_contacts
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
create policy emergency_contacts_delete_own on public.emergency_contacts
  for delete to authenticated
  using (profile_id = (select auth.uid()));

-- incidents
create policy incidents_select_reporter_participant_staff on public.incidents
  for select to authenticated
  using (
    reported_by = (select auth.uid())
    or (select public.has_permission('view_incidents'))
    or (job_id is not null and private.is_job_participant(job_id, (select auth.uid())))
  );
create policy incidents_insert_reporter on public.incidents
  for insert to authenticated
  with check (
    reported_by = (select auth.uid())
    and (job_id is null or private.is_job_participant(job_id, (select auth.uid())))
  );
create policy incidents_update_manage on public.incidents
  for update to authenticated
  using ((select public.has_permission('manage_incidents')))
  with check ((select public.has_permission('manage_incidents')));

-- incident_actions
create policy incident_actions_select_readable on public.incident_actions
  for select to authenticated
  using (private.can_read_incident(incident_id, (select auth.uid())));

-- blocked_users
create policy blocked_users_select_own on public.blocked_users
  for select to authenticated
  using (blocker_profile_id = (select auth.uid()));
create policy blocked_users_insert_own on public.blocked_users
  for insert to authenticated
  with check (blocker_profile_id = (select auth.uid()));
create policy blocked_users_update_own on public.blocked_users
  for update to authenticated
  using (blocker_profile_id = (select auth.uid()))
  with check (blocker_profile_id = (select auth.uid()));
create policy blocked_users_delete_own on public.blocked_users
  for delete to authenticated
  using (blocker_profile_id = (select auth.uid()));

-- prohibited_items
create policy prohibited_items_select_authenticated on public.prohibited_items
  for select to authenticated using (true);
create policy prohibited_items_insert_manage on public.prohibited_items
  for insert to authenticated
  with check ((select public.has_permission('manage_prohibited_items')));
create policy prohibited_items_update_manage on public.prohibited_items
  for update to authenticated
  using ((select public.has_permission('manage_prohibited_items')))
  with check ((select public.has_permission('manage_prohibited_items')));
create policy prohibited_items_delete_manage on public.prohibited_items
  for delete to authenticated
  using ((select public.has_permission('manage_prohibited_items')));

-- support_categories
create policy support_categories_select_authenticated on public.support_categories
  for select to authenticated using (true);
create policy support_categories_insert_manage on public.support_categories
  for insert to authenticated
  with check ((select public.has_permission('manage_support')));
create policy support_categories_update_manage on public.support_categories
  for update to authenticated
  using ((select public.has_permission('manage_support')))
  with check ((select public.has_permission('manage_support')));
create policy support_categories_delete_manage on public.support_categories
  for delete to authenticated
  using ((select public.has_permission('manage_support')));

-- support_tickets
create policy support_tickets_select_own_assigned_staff on public.support_tickets
  for select to authenticated
  using (
    opened_by = (select auth.uid())
    or assigned_to = (select auth.uid())
    or (select public.has_permission('view_all_tickets'))
  );
create policy support_tickets_insert_opener on public.support_tickets
  for insert to authenticated
  with check (opened_by = (select auth.uid()));
create policy support_tickets_update_manager_or_assignee on public.support_tickets
  for update to authenticated
  using (
    (select public.has_permission('manage_tickets'))
    or assigned_to = (select auth.uid())
  )
  with check (
    (select public.has_permission('manage_tickets'))
    or assigned_to = (select auth.uid())
  );

-- support_ticket_messages
create policy support_ticket_messages_select_readable on public.support_ticket_messages
  for select to authenticated
  using (
    private.can_read_support_ticket(ticket_id, (select auth.uid()))
    and (
      not is_internal_note
      or (select public.has_permission('view_all_tickets'))
    )
  );
create policy support_ticket_messages_insert_readable on public.support_ticket_messages
  for insert to authenticated
  with check (
    sender_profile_id = (select auth.uid())
    and private.can_read_support_ticket(ticket_id, (select auth.uid()))
    and (
      not is_internal_note
      or (select public.has_permission('view_all_tickets'))
    )
  );

-- data_access_log
create policy data_access_log_select_authorized on public.data_access_log
  for select to authenticated
  using ((select public.has_permission('view_data_access')));

-- retention_policies
create policy retention_policies_select_authorized on public.retention_policies
  for select to authenticated
  using ((select public.has_permission('view_retention')));
create policy retention_policies_insert_manage on public.retention_policies
  for insert to authenticated
  with check ((select public.has_permission('manage_retention')));
create policy retention_policies_update_manage on public.retention_policies
  for update to authenticated
  using ((select public.has_permission('manage_retention')))
  with check ((select public.has_permission('manage_retention')));
create policy retention_policies_delete_manage on public.retention_policies
  for delete to authenticated
  using ((select public.has_permission('manage_retention')));

-- data_subject_requests
create policy data_subject_requests_select_own_or_manage on public.data_subject_requests
  for select to authenticated
  using (
    requester_profile_id = (select auth.uid())
    or (select public.has_permission('manage_data_requests'))
  );
create policy data_subject_requests_insert_own on public.data_subject_requests
  for insert to authenticated
  with check (requester_profile_id = (select auth.uid()));
create policy data_subject_requests_update_manage on public.data_subject_requests
  for update to authenticated
  using ((select public.has_permission('manage_data_requests')))
  with check ((select public.has_permission('manage_data_requests')));

-- analytics
create policy daily_metrics_select_analytics on public.daily_metrics
  for select to authenticated
  using ((select public.has_permission('view_analytics')));
create policy zone_metrics_select_analytics on public.zone_metrics
  for select to authenticated
  using ((select public.has_permission('view_analytics')));
create policy driver_metrics_select_analytics on public.driver_metrics
  for select to authenticated
  using ((select public.has_permission('view_analytics')));
create policy customer_metrics_select_analytics on public.customer_metrics
  for select to authenticated
  using ((select public.has_permission('view_analytics')));
create policy demand_snapshots_select_analytics on public.demand_snapshots
  for select to authenticated
  using ((select public.has_permission('view_analytics')));

-- ----------------------------------------------------------------------------
-- 5. Grants
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

-- Supabase CLI migrations run as the postgres role, which carries default
-- privileges that grant ALL on new public tables to anon/authenticated. Remove
-- those defaults explicitly before applying the least-privilege grants below.
do $$
declare
  v_table text;
  v_sequence text;
  v_tables text[] := array[
    'push_tokens',
    'notification_templates',
    'notification_log',
    'notification_preferences',
    'chat_threads',
    'chat_messages',
    'chat_attachments',
    'chat_read_receipts',
    'emergency_contacts',
    'incidents',
    'incident_actions',
    'blocked_users',
    'prohibited_items',
    'support_categories',
    'support_tickets',
    'support_ticket_messages',
    'data_access_log',
    'retention_policies',
    'data_subject_requests',
    'daily_metrics',
    'zone_metrics',
    'driver_metrics',
    'customer_metrics',
    'demand_snapshots'
  ];
  v_sequences text[] := array[
    'notification_log_id_seq',
    'data_access_log_id_seq',
    'daily_metrics_id_seq',
    'zone_metrics_id_seq',
    'driver_metrics_id_seq',
    'customer_metrics_id_seq',
    'demand_snapshots_id_seq'
  ];
begin
  foreach v_table in array v_tables loop
    execute format('revoke all on table public.%I from anon, authenticated', v_table);
  end loop;

  foreach v_sequence in array v_sequences loop
    if to_regclass('public.' || v_sequence) is not null then
      execute format('revoke all on sequence public.%I from anon, authenticated', v_sequence);
      execute format('grant usage, select on sequence public.%I to service_role', v_sequence);
    end if;
  end loop;
end $$;

grant select, insert, update, delete on public.push_tokens to authenticated;
grant select, insert, update, delete on public.notification_templates to authenticated;
grant select on public.notification_log to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;
grant select on public.chat_threads to authenticated;
grant select, insert, update on public.chat_messages to authenticated;
grant select, insert on public.chat_attachments to authenticated;
grant select, insert, update, delete on public.chat_read_receipts to authenticated;
grant select, insert, update, delete on public.emergency_contacts to authenticated;
grant select, insert, update on public.incidents to authenticated;
grant select on public.incident_actions to authenticated;
grant select, insert, update, delete on public.blocked_users to authenticated;
grant select, insert, update, delete on public.prohibited_items to authenticated;
grant select, insert, update, delete on public.support_categories to authenticated;
grant select, insert, update on public.support_tickets to authenticated;
grant select, insert on public.support_ticket_messages to authenticated;
grant select on public.data_access_log to authenticated;
grant select, insert, update, delete on public.retention_policies to authenticated;
grant select, insert, update on public.data_subject_requests to authenticated;
grant select on public.daily_metrics to authenticated;
grant select on public.zone_metrics to authenticated;
grant select on public.driver_metrics to authenticated;
grant select on public.customer_metrics to authenticated;
grant select on public.demand_snapshots to authenticated;

grant all on public.push_tokens to service_role;
grant all on public.notification_templates to service_role;
grant all on public.notification_log to service_role;
grant all on public.notification_preferences to service_role;
grant all on public.chat_threads to service_role;
grant all on public.chat_messages to service_role;
grant all on public.chat_attachments to service_role;
grant all on public.chat_read_receipts to service_role;
grant all on public.emergency_contacts to service_role;
grant all on public.incidents to service_role;
grant all on public.incident_actions to service_role;
grant all on public.blocked_users to service_role;
grant all on public.prohibited_items to service_role;
grant all on public.support_categories to service_role;
grant all on public.support_tickets to service_role;
grant all on public.support_ticket_messages to service_role;
grant all on public.data_access_log to service_role;
grant all on public.retention_policies to service_role;
grant all on public.data_subject_requests to service_role;
grant all on public.daily_metrics to service_role;
grant all on public.zone_metrics to service_role;
grant all on public.driver_metrics to service_role;
grant all on public.customer_metrics to service_role;
grant all on public.demand_snapshots to service_role;
