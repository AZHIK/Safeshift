-- ============================================================================
-- SafeShift — Phase 4 / Migration 0073
-- RLS, permission catalogue and privileges for all 25 Phase 4 tables.
--
-- Rules:
--   * every table has RLS enabled and at least one policy
--   * policies use the cached (select auth.uid()) form
--   * direct client UPDATE is never granted on jobs
--   * direct client DELETE is never granted on any Phase 4 table
--   * immutable and server-written tables are SELECT-only for clients
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Permissions
-- ----------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('view_all_quotes',              'View every quote request and quote',                  'operations'),
  ('manage_surge',                 'Create and modify demand surge multipliers',          'pricing'),
  ('view_all_jobs',                'View every job and operational record',               'operations'),
  ('assign_drivers',               'Assign drivers and vehicles to jobs',                 'operations'),
  ('manage_cancellation_policies', 'Manage country cancellation policies',                'operations'),
  ('manage_dispatch',              'Manage dispatch rules and matching configuration',    'operations'),
  ('manage_ratings',               'Manage rating categories and moderation',             'support'),
  ('view_all_ratings',             'View every rating and rating report',                 'support'),
  ('view_all_disputes',            'View every dispute, including internal notes',        'support'),
  ('resolve_disputes',             'Resolve disputes and grant compensation',             'support')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'view_all_quotes', 'manage_surge', 'view_all_jobs', 'assign_drivers',
  'manage_cancellation_policies', 'manage_dispatch', 'manage_ratings',
  'view_all_ratings', 'view_all_disputes', 'resolve_disputes'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('operations_admin', 'view_all_quotes'),
  ('operations_admin', 'manage_surge'),
  ('operations_admin', 'view_all_jobs'),
  ('operations_admin', 'assign_drivers'),
  ('operations_admin', 'manage_cancellation_policies'),
  ('operations_admin', 'manage_dispatch'),
  ('operations_admin', 'view_all_ratings'),
  ('operations_admin', 'view_all_disputes'),
  ('support_agent',    'view_all_quotes'),
  ('support_agent',    'view_all_jobs'),
  ('support_agent',    'manage_ratings'),
  ('support_agent',    'view_all_ratings'),
  ('support_agent',    'view_all_disputes'),
  ('support_agent',    'resolve_disputes'),
  ('finance_admin',    'view_all_quotes'),
  ('finance_admin',    'view_all_jobs'),
  ('finance_admin',    'manage_cancellation_policies'),
  ('finance_admin',    'view_all_disputes'),
  ('analyst',          'view_all_quotes'),
  ('analyst',          'view_all_jobs'),
  ('analyst',          'view_all_ratings'),
  ('analyst',          'view_all_disputes'),
  ('verification_admin','view_all_jobs'),
  ('verification_admin','view_all_ratings')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- 2. Enable RLS
-- ----------------------------------------------------------------------------
alter table public.cancellation_policies      enable row level security;
alter table public.quote_requests             enable row level security;
alter table public.quotes                     enable row level security;
alter table public.surge_multipliers          enable row level security;
alter table public.jobs                       enable row level security;
alter table public.job_stops                  enable row level security;
alter table public.job_items                  enable row level security;
alter table public.job_evidence               enable row level security;
alter table public.job_status_history         enable row level security;
alter table public.job_events                 enable row level security;
alter table public.job_cancellations          enable row level security;
alter table public.driver_locations           enable row level security;
alter table public.matching_attempts          enable row level security;
alter table public.dispatch_rules             enable row level security;
alter table public.job_offers                 enable row level security;
alter table public.driver_acceptance_stats    enable row level security;
alter table public.rating_categories          enable row level security;
alter table public.ratings                    enable row level security;
alter table public.rating_reports             enable row level security;
alter table public.disputes                   enable row level security;
alter table public.dispute_messages           enable row level security;
alter table public.dispute_attachments        enable row level security;
alter table public.dispute_resolutions        enable row level security;
alter table public.recurring_job_templates    enable row level security;
alter table public.scheduled_jobs             enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Policies — quotes and pricing operations
-- ----------------------------------------------------------------------------
create policy quote_requests_select_own_or_staff
  on public.quote_requests for select to authenticated
  using (
    customer_id = (select auth.uid())
    or (select public.has_permission('view_all_quotes'))
  );

create policy quote_requests_insert_own
  on public.quote_requests for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy quotes_select_own_or_staff
  on public.quotes for select to authenticated
  using (
    exists (
      select 1 from public.quote_requests qr
      where qr.id = quotes.quote_request_id
        and qr.customer_id = (select auth.uid())
    )
    or (select public.has_permission('view_all_quotes'))
  );

create policy cancellation_policies_select_authenticated
  on public.cancellation_policies for select to authenticated
  using (true);

create policy cancellation_policies_manage
  on public.cancellation_policies for all to authenticated
  using ((select public.has_permission('manage_cancellation_policies')))
  with check ((select public.has_permission('manage_cancellation_policies')));

create policy surge_multipliers_select_authenticated
  on public.surge_multipliers for select to authenticated
  using (true);

create policy surge_multipliers_manage
  on public.surge_multipliers for all to authenticated
  using ((select public.has_permission('manage_surge')))
  with check ((select public.has_permission('manage_surge')));

-- ----------------------------------------------------------------------------
-- 4. Policies — jobs and their children
-- ----------------------------------------------------------------------------
create policy jobs_select_participant_or_staff
  on public.jobs for select to authenticated
  using (
    customer_id = (select auth.uid())
    or driver_id = (select auth.uid())
    or (select public.has_permission('view_all_jobs'))
  );

create policy jobs_insert_own_customer
  on public.jobs for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and exists (
      select 1
      from public.quotes q
      join public.quote_requests qr on qr.id = q.quote_request_id
      where q.id = jobs.quote_id
        and qr.customer_id = (select auth.uid())
    )
  );

create policy job_stops_select_participant_or_staff
  on public.job_stops for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_stops.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_stops_insert_participant
  on public.job_stops for insert to authenticated
  with check (
    exists (
      select 1 from public.jobs j
      where j.id = job_stops.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_items_select_participant_or_staff
  on public.job_items for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_items.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_items_insert_participant
  on public.job_items for insert to authenticated
  with check (
    exists (
      select 1 from public.jobs j
      where j.id = job_items.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_evidence_select_participant_or_staff
  on public.job_evidence for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_evidence.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_evidence_insert_participant
  on public.job_evidence for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.jobs j
      where j.id = job_evidence.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

create policy job_status_history_select_participant_or_staff
  on public.job_status_history for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_status_history.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_events_select_participant_or_staff
  on public.job_events for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_events.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_cancellations_select_participant_or_staff
  on public.job_cancellations for select to authenticated
  using (
    exists (
      select 1 from public.jobs j
      where j.id = job_cancellations.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 5. Policies — tracking and dispatch
-- ----------------------------------------------------------------------------
create policy driver_locations_select_self_participant_or_staff
  on public.driver_locations for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
    or exists (
      select 1 from public.jobs j
      where j.id = driver_locations.job_id
        and j.status not in ('completed', 'cancelled', 'disputed')
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

create policy driver_locations_insert_own
  on public.driver_locations for insert to authenticated
  with check (
    driver_id = (select auth.uid())
    and (
      job_id is null
      or exists (
        select 1 from public.jobs j
        where j.id = driver_locations.job_id
          and j.driver_id = (select auth.uid())
          and j.status not in ('completed', 'cancelled', 'disputed')
      )
    )
  );

create policy matching_attempts_select_staff
  on public.matching_attempts for select to authenticated
  using ((select public.has_permission('view_all_jobs')));

create policy dispatch_rules_select_authenticated
  on public.dispatch_rules for select to authenticated
  using (true);

create policy dispatch_rules_manage
  on public.dispatch_rules for all to authenticated
  using ((select public.has_permission('manage_dispatch')))
  with check ((select public.has_permission('manage_dispatch')));

create policy job_offers_select_driver_or_staff
  on public.job_offers for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_jobs'))
  );

create policy driver_acceptance_stats_select_driver_or_staff
  on public.driver_acceptance_stats for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (select public.has_permission('view_all_drivers'))
  );

-- ----------------------------------------------------------------------------
-- 6. Policies — ratings
-- ----------------------------------------------------------------------------
create policy rating_categories_select_authenticated
  on public.rating_categories for select to authenticated
  using (true);

create policy rating_categories_manage
  on public.rating_categories for all to authenticated
  using ((select public.has_permission('manage_ratings')))
  with check ((select public.has_permission('manage_ratings')));

create policy ratings_select_rater_rated_or_staff
  on public.ratings for select to authenticated
  using (
    rater_profile_id = (select auth.uid())
    or rated_profile_id = (select auth.uid())
    or (select public.has_permission('view_all_ratings'))
  );

create policy ratings_insert_counterparty
  on public.ratings for insert to authenticated
  with check (
    rater_profile_id = (select auth.uid())
    and exists (
      select 1 from public.jobs j
      where j.id = ratings.job_id
        and (
          (j.customer_id = (select auth.uid()) and j.driver_id = ratings.rated_profile_id)
          or (j.driver_id = (select auth.uid()) and j.customer_id = ratings.rated_profile_id)
        )
    )
  );

create policy rating_reports_select_reporter_or_staff
  on public.rating_reports for select to authenticated
  using (
    reported_by = (select auth.uid())
    or (select public.has_permission('view_all_ratings'))
  );

create policy rating_reports_insert_reporter
  on public.rating_reports for insert to authenticated
  with check (reported_by = (select auth.uid()));

create policy rating_reports_update_manage
  on public.rating_reports for update to authenticated
  using ((select public.has_permission('manage_ratings')))
  with check ((select public.has_permission('manage_ratings')));

-- ----------------------------------------------------------------------------
-- 7. Policies — disputes
-- ----------------------------------------------------------------------------
create policy disputes_select_party_or_staff
  on public.disputes for select to authenticated
  using (
    raised_by = (select auth.uid())
    or (select public.has_permission('view_all_disputes'))
    or exists (
      select 1 from public.jobs j
      where j.id = disputes.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

create policy disputes_insert_party
  on public.disputes for insert to authenticated
  with check (
    raised_by = (select auth.uid())
    and exists (
      select 1 from public.jobs j
      where j.id = disputes.job_id
        and (
          j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

create policy disputes_update_resolver
  on public.disputes for update to authenticated
  using ((select public.has_permission('resolve_disputes')))
  with check ((select public.has_permission('resolve_disputes')));

create policy dispute_messages_select_party_or_staff
  on public.dispute_messages for select to authenticated
  using (
    (select public.has_permission('view_all_disputes'))
    or (
      not is_internal_note
      and exists (
        select 1
        from public.disputes d
        join public.jobs j on j.id = d.job_id
        where d.id = dispute_messages.dispute_id
          and (
            d.raised_by = (select auth.uid())
            or j.customer_id = (select auth.uid())
            or j.driver_id = (select auth.uid())
          )
      )
    )
  );

create policy dispute_messages_insert_party_or_staff
  on public.dispute_messages for insert to authenticated
  with check (
    sender_profile_id = (select auth.uid())
    and (
      (select public.has_permission('view_all_disputes'))
      or (
        not is_internal_note
        and exists (
          select 1
          from public.disputes d
          join public.jobs j on j.id = d.job_id
          where d.id = dispute_messages.dispute_id
            and (
              d.raised_by = (select auth.uid())
              or j.customer_id = (select auth.uid())
              or j.driver_id = (select auth.uid())
            )
        )
      )
    )
  );

create policy dispute_attachments_select_party_or_staff
  on public.dispute_attachments for select to authenticated
  using (
    (select public.has_permission('view_all_disputes'))
    or exists (
      select 1
      from public.disputes d
      join public.jobs j on j.id = d.job_id
      where d.id = dispute_attachments.dispute_id
        and (
          d.raised_by = (select auth.uid())
          or j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

create policy dispute_attachments_insert_party_or_staff
  on public.dispute_attachments for insert to authenticated
  with check (
    uploaded_by = (select auth.uid())
    and (
      (select public.has_permission('view_all_disputes'))
      or exists (
        select 1
        from public.disputes d
        join public.jobs j on j.id = d.job_id
        where d.id = dispute_attachments.dispute_id
          and (
            d.raised_by = (select auth.uid())
            or j.customer_id = (select auth.uid())
            or j.driver_id = (select auth.uid())
          )
      )
    )
  );

create policy dispute_resolutions_select_party_or_staff
  on public.dispute_resolutions for select to authenticated
  using (
    (select public.has_permission('view_all_disputes'))
    or exists (
      select 1
      from public.disputes d
      join public.jobs j on j.id = d.job_id
      where d.id = dispute_resolutions.dispute_id
        and (
          d.raised_by = (select auth.uid())
          or j.customer_id = (select auth.uid())
          or j.driver_id = (select auth.uid())
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 8. Policies — recurring jobs
-- ----------------------------------------------------------------------------
create policy recurring_job_templates_select_member_or_staff
  on public.recurring_job_templates for select to authenticated
  using (
    (select public.is_business_member(business_account_id))
    or (select public.has_permission('manage_business_accounts'))
  );

create policy recurring_job_templates_insert_admin
  on public.recurring_job_templates for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and (
      (select public.is_business_admin(business_account_id))
      or (select public.has_permission('manage_business_accounts'))
    )
  );

create policy recurring_job_templates_update_admin
  on public.recurring_job_templates for update to authenticated
  using (
    (select public.is_business_admin(business_account_id))
    or (select public.has_permission('manage_business_accounts'))
  )
  with check (
    (select public.is_business_admin(business_account_id))
    or (select public.has_permission('manage_business_accounts'))
  );

create policy scheduled_jobs_select_template_member_or_staff
  on public.scheduled_jobs for select to authenticated
  using (
    (select public.has_permission('view_all_jobs'))
    or exists (
      select 1 from public.recurring_job_templates t
      where t.id = scheduled_jobs.template_id
        and (
          (select public.is_business_member(t.business_account_id))
          or (select public.has_permission('manage_business_accounts'))
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 9. Privileges
-- ----------------------------------------------------------------------------
revoke all on
  public.cancellation_policies,
  public.quote_requests,
  public.quotes,
  public.surge_multipliers,
  public.jobs,
  public.job_stops,
  public.job_items,
  public.job_evidence,
  public.job_status_history,
  public.job_events,
  public.job_cancellations,
  public.driver_locations,
  public.matching_attempts,
  public.dispatch_rules,
  public.job_offers,
  public.driver_acceptance_stats,
  public.rating_categories,
  public.ratings,
  public.rating_reports,
  public.disputes,
  public.dispute_messages,
  public.dispute_attachments,
  public.dispute_resolutions,
  public.recurring_job_templates,
  public.scheduled_jobs
from anon, authenticated;

grant select on
  public.cancellation_policies,
  public.quote_requests,
  public.quotes,
  public.surge_multipliers,
  public.jobs,
  public.job_stops,
  public.job_items,
  public.job_evidence,
  public.job_status_history,
  public.job_events,
  public.job_cancellations,
  public.driver_locations,
  public.matching_attempts,
  public.dispatch_rules,
  public.job_offers,
  public.driver_acceptance_stats,
  public.rating_categories,
  public.ratings,
  public.rating_reports,
  public.disputes,
  public.dispute_messages,
  public.dispute_attachments,
  public.dispute_resolutions,
  public.recurring_job_templates,
  public.scheduled_jobs
to authenticated;

grant insert on
  public.cancellation_policies,
  public.quote_requests,
  public.surge_multipliers,
  public.jobs,
  public.job_stops,
  public.job_items,
  public.job_evidence,
  public.driver_locations,
  public.dispatch_rules,
  public.rating_categories,
  public.ratings,
  public.rating_reports,
  public.disputes,
  public.dispute_messages,
  public.dispute_attachments,
  public.recurring_job_templates
to authenticated;

grant update on
  public.cancellation_policies,
  public.surge_multipliers,
  public.dispatch_rules,
  public.rating_categories,
  public.rating_reports,
  public.disputes,
  public.recurring_job_templates
to authenticated;

-- Partition children do not inherit the parent's RLS policies. Clients access
-- them only through the partitioned parent, so direct privileges are revoked.
do $$
declare
  v_partition record;
begin
  for v_partition in
    select c.oid::regclass as rel
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relispartition
  loop
    execute format('revoke all on table %s from anon, authenticated', v_partition.rel);
  end loop;
end $$;

comment on policy jobs_insert_own_customer on public.jobs is
  'Authenticated customers may create the initial requested state from their own unexpired quote. UPDATE is intentionally not granted; helpers own all transitions.';
