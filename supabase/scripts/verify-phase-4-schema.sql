-- ============================================================================
-- SafeShift — Phase 4 schema verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-4-schema.sql
--
-- Run after migrations and after seed.sql + seed-phase-2.sql +
-- seed-phase-3.sql + seed-phase-4.sql. Read-only with respect to seeded rows;
-- behavioural checks create random scratch quotes/jobs that are intentionally
-- left behind because quotes are append-only. Seed-count checks are scoped to
-- fixed seed identifiers so repeated runs remain meaningful.
-- ============================================================================

drop table if exists _phase4_verification;
create temporary table _phase4_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

drop table if exists _phase4_scratch;
create temporary table _phase4_scratch (
  key text primary key,
  id uuid not null
);

-- ----------------------------------------------------------------------------
-- 1. Enums
-- ----------------------------------------------------------------------------
insert into _phase4_verification (check_no, check_name, status, details)
select 1, 'Enum public.' || e.typname,
       case when v.labels is not null and v.labels = e.expected then 'PASS' else 'FAIL' end,
       coalesce(array_to_string(v.labels, ','), 'missing')
from (values
  ('job_status', array['requested','quoted','matched','accepted','heading_to_pickup','arrived','loading','in_transit','delivered','completed','cancelled','disputed']),
  ('payment_status', array['pending','paid','refunded','failed','partially_refunded']),
  ('payment_method', array['mpesa','tigopesa','airtelmoney','halopesa','card','cash','wallet']),
  ('evidence_type', array['pickup_photo','delivery_photo','signature','otp','document','item_photo','cargo_manifest']),
  ('trip_alert_type', array['route_deviation','prolonged_stop','sos','unusual_activity'])
) as e(typname, expected)
left join lateral (
  select array_agg(en.enumlabel::text order by en.enumsortorder) as labels
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  join pg_enum en on en.enumtypid = t.oid
  where n.nspname = 'public' and t.typname = e.typname
) v on true;

insert into _phase4_verification (check_no, check_name, status, details)
select 1, 'All five operational enums installed',
       case when count(*) = 5 then 'PASS' else 'FAIL' end,
       count(*) || ' of 5'
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typtype = 'e'
  and t.typname in ('job_status','payment_status','payment_method','evidence_type','trip_alert_type');

-- ----------------------------------------------------------------------------
-- 2. Tables, RLS and policies
-- ----------------------------------------------------------------------------
create temporary table _phase4_tables (name text primary key);
insert into _phase4_tables (name) values
  ('cancellation_policies'), ('quote_requests'), ('quotes'), ('surge_multipliers'),
  ('jobs'), ('job_stops'), ('job_items'), ('job_evidence'), ('job_status_history'),
  ('job_events'), ('job_cancellations'), ('driver_locations'), ('matching_attempts'),
  ('dispatch_rules'), ('job_offers'), ('driver_acceptance_stats'),
  ('rating_categories'), ('ratings'), ('rating_reports'), ('disputes'),
  ('dispute_messages'), ('dispute_attachments'), ('dispute_resolutions'),
  ('recurring_job_templates'), ('scheduled_jobs');

insert into _phase4_verification (check_no, check_name, status, details)
select 2, 'All 25 Phase 4 tables exist',
       case when count(*) = 25 then 'PASS' else 'FAIL' end,
       count(*) || ' of 25 present'
from _phase4_tables t
where to_regclass('public.' || t.name) is not null;

insert into _phase4_verification (check_no, check_name, status, details)
select 3, 'RLS enabled on ' || t.name,
       case when c.relrowsecurity then 'PASS' else 'FAIL' end,
       c.relkind::text
from _phase4_tables t
left join pg_class c on c.oid = to_regclass('public.' || t.name)
order by t.name;

insert into _phase4_verification (check_no, check_name, status, details)
select 4, 'At least one policy on ' || t.name,
       case when exists (
         select 1 from pg_policy p where p.polrelid = to_regclass('public.' || t.name)
       ) then 'PASS' else 'FAIL' end,
       (select count(*)::text || ' policies' from pg_policy p
        where p.polrelid = to_regclass('public.' || t.name))
from _phase4_tables t
order by t.name;

insert into _phase4_verification (check_no, check_name, status, details)
select 5, 'Partition children have no client privileges',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'no direct client access')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relispartition
  and (
    has_table_privilege('anon', c.oid, 'SELECT')
    or has_table_privilege('anon', c.oid, 'INSERT')
    or has_table_privilege('anon', c.oid, 'UPDATE')
    or has_table_privilege('anon', c.oid, 'DELETE')
    or has_table_privilege('authenticated', c.oid, 'SELECT')
    or has_table_privilege('authenticated', c.oid, 'INSERT')
    or has_table_privilege('authenticated', c.oid, 'UPDATE')
    or has_table_privilege('authenticated', c.oid, 'DELETE')
  );

insert into _phase4_verification (check_no, check_name, status, details)
select 6, 'No client DELETE grant on any Phase 4 table',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t.name, ', '), 'no DELETE grants')
from _phase4_tables t
where has_table_privilege('anon', 'public.' || t.name, 'DELETE')
   or has_table_privilege('authenticated', 'public.' || t.name, 'DELETE');

insert into _phase4_verification (check_no, check_name, status, details)
select 7, 'jobs: INSERT granted, UPDATE/DELETE withheld',
       case when has_table_privilege('authenticated', 'public.jobs', 'INSERT')
                  and not has_table_privilege('authenticated', 'public.jobs', 'UPDATE')
                  and not has_table_privilege('authenticated', 'public.jobs', 'DELETE')
            then 'PASS' else 'FAIL' end,
       'insert=' || has_table_privilege('authenticated', 'public.jobs', 'INSERT')::text
       || ', update=' || has_table_privilege('authenticated', 'public.jobs', 'UPDATE')::text
       || ', delete=' || has_table_privilege('authenticated', 'public.jobs', 'DELETE')::text;

insert into _phase4_verification (check_no, check_name, status, details)
select 8, 'quotes are SELECT-only for authenticated',
       case when has_table_privilege('authenticated', 'public.quotes', 'SELECT')
                  and not has_table_privilege('authenticated', 'public.quotes', 'INSERT')
                  and not has_table_privilege('authenticated', 'public.quotes', 'UPDATE')
                  and not has_table_privilege('authenticated', 'public.quotes', 'DELETE')
            then 'PASS' else 'FAIL' end,
       'insert=' || has_table_privilege('authenticated', 'public.quotes', 'INSERT')::text
       || ', update=' || has_table_privilege('authenticated', 'public.quotes', 'UPDATE')::text
       || ', delete=' || has_table_privilege('authenticated', 'public.quotes', 'DELETE')::text;

insert into _phase4_verification (check_no, check_name, status, details)
select 9, 'Server-written tables have no client write grant',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t.name, ', '), 'append-only for clients')
from _phase4_tables t
where t.name in (
  'quotes', 'job_status_history', 'job_events', 'job_cancellations',
  'matching_attempts', 'job_offers', 'driver_acceptance_stats',
  'dispute_resolutions', 'scheduled_jobs'
)
and (
  has_table_privilege('authenticated', 'public.' || t.name, 'INSERT')
  or has_table_privilege('authenticated', 'public.' || t.name, 'UPDATE')
  or has_table_privilege('authenticated', 'public.' || t.name, 'DELETE')
);

insert into _phase4_verification (check_no, check_name, status, details)
select 10, 'Phase 4 policies use cached (select auth.uid())',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(tablename || '.' || policyname, ', '), 'cached form everywhere')
from pg_policies
where schemaname = 'public'
  and tablename in (select name from _phase4_tables)
  and (
    (coalesce(qual, '') like '%auth.uid()%'
      and lower(coalesce(qual, '')) not like '%select auth.uid()%')
    or
    (coalesce(with_check, '') like '%auth.uid()%'
      and lower(coalesce(with_check, '')) not like '%select auth.uid()%')
  );

-- ----------------------------------------------------------------------------
-- 3. Column types, partitioning and numeric precision
-- ----------------------------------------------------------------------------
insert into _phase4_verification (check_no, check_name, status, details)
select 11, 'No FLOAT/DOUBLE columns in Phase 4 tables',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(table_name || '.' || column_name, ', '), 'all NUMERIC/integer/text')
from information_schema.columns
where table_schema = 'public'
  and table_name in (select name from _phase4_tables)
  and data_type in ('real', 'double precision');

insert into _phase4_verification (check_no, check_name, status, details)
select 12, 'Money columns use NUMERIC(14,2)',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(x.tbl || '.' || x.col, ', '), 'all money columns NUMERIC(14,2)')
from (values
  ('quotes','base_fare'), ('quotes','distance_charge'), ('quotes','time_charge'),
  ('quotes','weight_surcharge'), ('quotes','volume_surcharge'), ('quotes','cargo_surcharge'),
  ('quotes','equipment_surcharge'), ('quotes','waiting_charge'), ('quotes','multi_stop_charge'),
  ('quotes','promo_discount'), ('quotes','subtotal'), ('quotes','vat'), ('quotes','total'),
  ('quotes','regulated_max_fare'),
  ('jobs','final_amount'), ('jobs','cancellation_fee'),
  ('job_items','declared_value'),
  ('job_cancellations','fee_applied'), ('job_cancellations','refund_amount'),
  ('job_offers','payout_estimate'), ('disputes','compensation_amount')
) as x(tbl, col)
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = x.tbl and c.column_name = x.col
where c.column_name is null
   or c.data_type <> 'numeric'
   or c.numeric_precision <> 14
   or c.numeric_scale <> 2;

insert into _phase4_verification (check_no, check_name, status, details)
select 13, 'Multipliers use NUMERIC(6,4)',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(x.tbl || '.' || x.col, ', '), 'all multipliers NUMERIC(6,4)')
from (values
  ('quotes','zone_multiplier'), ('quotes','time_multiplier'), ('quotes','surge_multiplier'),
  ('surge_multipliers','multiplier')
) as x(tbl, col)
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = x.tbl and c.column_name = x.col
where c.column_name is null
   or c.data_type <> 'numeric'
   or c.numeric_precision <> 6
   or c.numeric_scale <> 4;

insert into _phase4_verification (check_no, check_name, status, details)
select 14, 'driver_locations has exactly 6 monthly partitions',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       count(*) || ' monthly partition(s) plus default'
from pg_partition_tree('public.driver_locations'::regclass) pt
join pg_class c on c.oid = pt.relid
where pt.isleaf and c.relname not like '%_default';

insert into _phase4_verification (check_no, check_name, status, details)
select 15, 'job_events has exactly 12 monthly partitions',
       case when count(*) = 12 then 'PASS' else 'FAIL' end,
       count(*) || ' monthly partition(s) plus default'
from pg_partition_tree('public.job_events'::regclass) pt
join pg_class c on c.oid = pt.relid
where pt.isleaf and c.relname not like '%_default';

insert into _phase4_verification (check_no, check_name, status, details)
select 16, 'Partitioned primary keys include the partition key',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t.tbl || ': ' || pg_get_constraintdef(con.oid), '; '), 'missing')
from (values ('driver_locations','recorded_at'), ('job_events','created_at')) t(tbl, part_key)
left join pg_constraint con
  on con.conrelid = to_regclass('public.' || t.tbl)
 and con.contype = 'p'
where pg_get_constraintdef(con.oid) like '%id%'
  and pg_get_constraintdef(con.oid) like '%' || t.part_key || '%';

insert into _phase4_verification (check_no, check_name, status, details)
select 17, 'Partition children exist for current month',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(c.relname, ', '), 'missing current-month partitions')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'job_events_' || to_char(now(), 'YYYY_MM'),
    'driver_locations_' || to_char(now(), 'YYYY_MM')
  );

-- ----------------------------------------------------------------------------
-- 4. Functions, triggers, indexes and views
-- ----------------------------------------------------------------------------
create temporary table _phase4_functions (name text primary key);
insert into _phase4_functions (name) values
  ('is_service_context'), ('quote_calculate_core'), ('quote_calculate_and_persist'),
  ('quote_get_breakdown'), ('refresh_driver_acceptance_stats'),
  ('sync_driver_acceptance_stats'), ('prepare_job_insert'), ('job_assign_driver'),
  ('job_cancel'), ('job_advance_status'), ('dispatch_rule_for'),
  ('find_nearby_drivers'), ('offer_job_to_driver'), ('accept_job_offer'),
  ('decline_job_offer'), ('expire_stale_offers'), ('recompute_driver_rating'),
  ('sync_driver_current_location');

insert into _phase4_verification (check_no, check_name, status, details)
select 18, 'Phase 4 SECURITY DEFINER functions exist',
       case when count(*) = 18 then 'PASS' else 'FAIL' end,
       count(*) || ' of 18 present'
from _phase4_functions f
where exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and p.proname = f.name
);

insert into _phase4_verification (check_no, check_name, status, details)
select 19, 'Every Phase 4 helper is SECURITY DEFINER',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(f.name, ', '), 'all security definer')
from _phase4_functions f
left join lateral (
  select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and p.proname = f.name
  order by n.nspname limit 1
) p on true
where p.prosecdef is distinct from true;

insert into _phase4_verification (check_no, check_name, status, details)
select 20, 'Every Phase 4 helper pins search_path',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(f.name, ', '), 'search_path pinned')
from _phase4_functions f
left join lateral (
  select p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and p.proname = f.name
  order by n.nspname limit 1
) p on true
where p.proconfig is null
   or not (array_to_string(p.proconfig, ',') like '%search_path=%');

insert into _phase4_verification (check_no, check_name, status, details)
select 21, 'Append-only triggers installed',
       case when count(*) = 5 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(t.tbl || '.' || t.trg, ', '), 'missing')
from (values
  ('quotes','trg_quotes_immutable'),
  ('job_status_history','trg_job_status_history_immutable'),
  ('job_events','trg_job_events_immutable'),
  ('job_offers','trg_job_offers_immutable'),
  ('dispute_resolutions','trg_dispute_resolutions_immutable')
) t(tbl, trg)
join pg_trigger tg on tg.tgname = t.trg
join pg_class c on c.oid = tg.tgrelid
where c.oid = to_regclass('public.' || t.tbl);

insert into _phase4_verification (check_no, check_name, status, details)
select 22, 'Driver location protection and current-location triggers installed',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 triggers'
from pg_trigger
where tgrelid = 'public.driver_locations'::regclass
  and tgname in (
    'trg_driver_locations_protect_fields',
    'trg_driver_locations_sync_current'
  );

insert into _phase4_verification (check_no, check_name, status, details)
select 23, 'private.audit_trigger reused on mutable roots',
       case when count(*) = 9 then 'PASS' else 'FAIL' end,
       count(*) || ' of 9 audit triggers'
from pg_trigger tg
join pg_class c on c.oid = tg.tgrelid
join pg_proc p on p.oid = tg.tgfoid
where p.proname = 'audit_trigger'
  and c.relname in (
    'jobs','cancellation_policies','surge_multipliers','dispatch_rules',
    'rating_categories','rating_reports','disputes','recurring_job_templates','scheduled_jobs'
  )
  and not tg.tgisinternal;

create temporary table _phase4_indexes (name text primary key);
insert into _phase4_indexes (name) values
  ('idx_quote_requests_customer_requested'), ('idx_quote_requests_city_requested'),
  ('idx_quotes_request'), ('idx_quotes_expires'), ('idx_surge_city_window'),
  ('idx_jobs_customer_created'), ('idx_jobs_driver_status'), ('idx_jobs_status_created'),
  ('idx_jobs_city_status'), ('idx_jobs_scheduled_active'), ('idx_jobs_quote'),
  ('idx_job_evidence_job'), ('idx_job_status_history_job_created'),
  ('idx_job_events_job_created'), ('idx_driver_locations_driver_recorded'),
  ('idx_matching_attempts_job_started'), ('idx_job_offers_driver_response'),
  ('idx_job_offers_pending'), ('idx_ratings_rated_created'),
  ('idx_disputes_status_priority_created'), ('idx_dispute_messages_dispute_created'),
  ('idx_scheduled_jobs_status_due');

insert into _phase4_verification (check_no, check_name, status, details)
select 24, 'Phase 4 query-path indexes exist',
       case when count(*) = 22 then 'PASS' else 'FAIL' end,
       count(*) || ' of 22 named indexes'
from _phase4_indexes i
where to_regclass('public.' || i.name) is not null;

insert into _phase4_verification (check_no, check_name, status, details)
select 25, 'GIST indexes cover geographic columns',
       case when count(distinct tablename) >= 4 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(tablename, ', '), 'missing')
from pg_indexes
where schemaname = 'public'
  and indexdef like '%USING gist%'
  and tablename in ('quote_requests','job_stops','job_events','driver_locations');

create temporary table _phase4_views (name text primary key, expected_columns integer not null);
insert into _phase4_views (name, expected_columns) values
  ('job_summary', 11),
  ('active_jobs_by_driver', 6),
  ('driver_dashboard_summary', 8),
  ('quote_summary', 8),
  ('dispute_summary', 9),
  ('matching_performance', 5);

insert into _phase4_verification (check_no, check_name, status, details)
select 26, 'Phase 4 views use security_invoker',
       case when count(*) = 6 then 'PASS' else 'FAIL' end,
       count(*) || ' of 6 views'
from _phase4_views v
join pg_class c on c.oid = to_regclass('public.' || v.name)
where c.relkind = 'v'
  and array_to_string(coalesce(c.reloptions, '{}'), ',') like '%security_invoker=true%';

insert into _phase4_verification (check_no, check_name, status, details)
select 27, 'View ' || v.name || ' has expected column count',
       case when count(c.column_name) = v.expected_columns then 'PASS' else 'FAIL' end,
       count(c.column_name) || ' of ' || v.expected_columns
from _phase4_views v
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = v.name
group by v.name, v.expected_columns
order by v.name;

insert into _phase4_verification (check_no, check_name, status, details)
select 28, 'dispute_summary exposes assigned_to_name',
       case when count(*) = 1 then 'PASS' else 'FAIL' end,
       'documented alias of resolved_by'
from information_schema.columns
where table_schema = 'public' and table_name = 'dispute_summary'
  and column_name = 'assigned_to_name';

-- ----------------------------------------------------------------------------
-- 5. Seed fixtures (fixed ids keep these checks stable across repeated runs)
-- ----------------------------------------------------------------------------
insert into _phase4_verification (check_no, check_name, status, details)
select 29, 'Seed: ' || s.label,
       case when s.actual = s.expected then 'PASS' else 'FAIL' end,
       s.actual || ' of ' || s.expected
from (values
  ('cancellation policies', (select count(*) from public.cancellation_policies where id::text like '4a000000%'), 2::bigint),
  ('rating categories', (select count(*) from public.rating_categories where id::text like '4c000000%'), 5),
  ('dispatch rules', (select count(*) from public.dispatch_rules where id::text like '4d000000%'), 1),
  ('quote requests', (select count(*) from public.quote_requests where id::text like '4b000000%'), 3),
  ('accepted quote requests', (select count(*) from public.quote_requests where id::text like '4b000000%' and metadata->>'outcome' = 'accepted'), 2),
  ('abandoned quote requests', (select count(*) from public.quote_requests where id::text like '4b000000%' and metadata->>'outcome' = 'abandoned'), 1),
  ('quotes', (select count(*) from public.quotes where id::text like '4e000000%'), 2),
  ('jobs', (select count(*) from public.jobs where id::text like '4f000000%'), 3),
  ('completed jobs', (select count(*) from public.jobs where id::text like '4f000000%' and status = 'completed'), 1),
  ('in-transit jobs', (select count(*) from public.jobs where id::text like '4f000000%' and status = 'in_transit'), 1),
  ('cancelled jobs', (select count(*) from public.jobs where id::text like '4f000000%' and status = 'cancelled'), 1),
  ('job stops', (select count(*) from public.job_stops where id::text like '5a000000%'), 6),
  ('job items', (select count(*) from public.job_items where id::text like '5b000000%'), 3),
  ('job evidence', (select count(*) from public.job_evidence where id::text like '5c000000%'), 4),
  ('status history rows', (select count(*) from public.job_status_history where job_id::text like '4f000000%'), 16),
  ('lifecycle events', (select count(*) from public.job_events where job_id::text like '4f000000%'), 15),
  ('job cancellations', (select count(*) from public.job_cancellations where id::text like '5d000000%'), 1),
  ('driver location pings', (select count(*) from public.driver_locations where job_id is null and driver_id in ('d0000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000003')), 15),
  ('matching attempts', (select count(*) from public.matching_attempts where id::text like '5e000000%'), 2),
  ('job offers', (select count(*) from public.job_offers where id::text like '5f000000%'), 2),
  ('accepted offers', (select count(*) from public.job_offers where id::text like '5f000000%' and response = 'accepted'), 1),
  ('auto-reassigned offers', (select count(*) from public.job_offers where id::text like '5f000000%' and response = 'auto_reassigned'), 1),
  ('driver acceptance stats', (select count(*) from public.driver_acceptance_stats where driver_id in ('d0000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000003')), 3),
  ('ratings', (select count(*) from public.ratings where id::text like '6a000000%'), 4),
  ('open disputes', (select count(*) from public.disputes where id::text like '6b000000%' and status = 'open'), 1),
  ('dispute messages', (select count(*) from public.dispute_messages where id::text like '6c000000%'), 3),
  ('internal dispute notes', (select count(*) from public.dispute_messages where id::text like '6c000000%' and is_internal_note), 1),
  ('recurring templates', (select count(*) from public.recurring_job_templates where id::text like '6d000000%'), 1),
  ('scheduled jobs', (select count(*) from public.scheduled_jobs where id::text like '6e000000%' and status = 'pending'), 3)
) as s(label, actual, expected);

insert into _phase4_verification (check_no, check_name, status, details)
select 30, 'Seed: quote 2 backs the in-transit and cancelled jobs',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' jobs'
from public.jobs
where quote_id = '4e000000-0000-4000-8000-000000000002'
  and id::text like '4f000000%'
  and status in ('in_transit', 'cancelled');

insert into _phase4_verification (check_no, check_name, status, details)
select 31, 'Seed: abandoned request has no quote',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       count(*) || ' quote(s)'
from public.quotes
where quote_request_id = '4b000000-0000-4000-8000-000000000003';

insert into _phase4_verification (check_no, check_name, status, details)
select 32, 'Seed: cancellation fee is 20% of quote 2',
       case when j.cancellation_fee = round(q.total * 0.20, 2)
                 and c.fee_applied = j.cancellation_fee
                 and c.canceller_role = 'customer'
            then 'PASS' else 'FAIL' end,
       'job=' || j.cancellation_fee || ', record=' || c.fee_applied
from public.jobs j
join public.quotes q on q.id = j.quote_id
join public.job_cancellations c on c.job_id = j.id
where j.id = '4f000000-0000-4000-8000-000000000003';

insert into _phase4_verification (check_no, check_name, status, details)
select 33, 'Seed: quote totals are internally consistent',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(id::text, ', '), 'subtotal - discount + vat = total')
from public.quotes
where id::text like '4e000000%'
  and total <> round(subtotal - promo_discount + vat, 2);

insert into _phase4_verification (check_no, check_name, status, details)
select 34, 'Seed: scheduled occurrences are future-dated and distinct',
       case when count(*) = 3 and count(distinct scheduled_for) = 3
                 and bool_and(scheduled_for > now())
            then 'PASS' else 'FAIL' end,
       count(*) || ' occurrence(s)'
from public.scheduled_jobs
where id::text like '6e000000%';

-- ----------------------------------------------------------------------------
-- 6. Authoritative quote engine
-- ----------------------------------------------------------------------------
do $$
declare
  v_qid  uuid;
  v_q    public.quotes%rowtype;
  v_snap jsonb;
begin
  v_qid := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000003',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo Market',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
    'Mlimani City',
    '22000000-0000-4000-8000-000000000001',
    '25000000-0000-4000-8000-000000000001',
    300, 2, null, 2, 0, '{}'::uuid[],
    '37000000-0000-4000-8000-000000000001', 8.5, 25
  );

  select * into v_q from public.quotes where id = v_qid;
  v_snap := public.quote_get_breakdown(v_qid);

  insert into _phase4_scratch values ('promo_quote', v_qid);

  insert into _phase4_verification values (
    35, 'Quote engine applies one promo to the discounted net',
    case when v_q.promo_code_id = '37000000-0000-4000-8000-000000000001'
              and v_q.promo_discount > 0
              and v_q.total = round(v_q.subtotal - v_q.promo_discount + v_q.vat, 2)
              and (v_snap #>> '{promo,applied}')::boolean
              and (v_snap #>> '{promo,promo_code_id}') = '37000000-0000-4000-8000-000000000001'
         then 'PASS' else 'FAIL' end,
    'discount=' || v_q.promo_discount || ', total=' || v_q.total
  );

  insert into _phase4_verification values (
    36, 'Quote snapshot contains every decision section',
    case when v_snap ? 'inputs' and v_snap ? 'plan' and v_snap ? 'calculation'
              and v_snap ? 'surge' and v_snap ? 'promo' and v_snap ? 'final'
         then 'PASS' else 'FAIL' end,
    array_to_string(array(select jsonb_object_keys(v_snap)), ',')
  );
exception when others then
  insert into _phase4_verification values (35, 'Quote engine applies one promo to the discounted net', 'FAIL', sqlerrm);
  insert into _phase4_verification values (36, 'Quote snapshot contains every decision section', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  begin
    perform public.quote_calculate_and_persist(
      'c0000000-0000-4000-8000-000000000003',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
      'Kariakoo Market',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
      'Mlimani City',
      '22000000-0000-4000-8000-000000000001',
      '25000000-0000-4000-8000-000000000001',
      300, 2, null, 2, 0, '{}'::uuid[],
      '37000000-0000-4000-8000-000000000005', 8.5, 25
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase4_verification values (
    37, 'Quote engine rejects an expired promo',
    case when v_blocked and v_error ilike '%not valid%' then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'expired promo unexpectedly accepted')
  );
end $$;

do $$
declare
  v_qid   uuid;
  v_q     public.quotes%rowtype;
  v_snap  jsonb;
  v_pre   numeric;
begin
  v_qid := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000003',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    'Kariakoo Market',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.3450 -6.6500)'),
    'Outside-city test destination',
    '22000000-0000-4000-8000-000000000005',
    '25000000-0000-4000-8000-000000000006',
    5000, 30, date_trunc('day', now()) + interval '11 hours',
    2, 0, '{}'::uuid[], null, 90, 120
  );

  select * into v_q from public.quotes where id = v_qid;
  v_snap := public.quote_get_breakdown(v_qid);
  v_pre := (v_snap #>> '{calculation,breakdown_details,pre_regulated_total}')::numeric;

  insert into _phase4_scratch values ('cap_quote', v_qid);

  insert into _phase4_verification values (
    38, 'LATRA cap is applied to the total including VAT',
    case when v_q.is_capped
              and v_q.regulated_max_fare = 350000.00
              and v_q.total = 350000.00
              and v_q.subtotal = round(v_q.total / 1.18, 2)
              and v_q.vat = round(v_q.total - v_q.subtotal, 2)
              and v_pre > v_q.total
         then 'PASS' else 'FAIL' end,
    'pre=' || coalesce(v_pre::text, 'null') || ', cap=' || coalesce(v_q.regulated_max_fare::text, 'null') || ', total=' || v_q.total
  );

  insert into _phase4_verification values (
    39, 'Quote expires exactly 15 minutes after creation',
    case when v_q.expires_at = v_q.created_at + interval '15 minutes'
         then 'PASS' else 'FAIL' end,
    v_q.created_at::text || ' -> ' || v_q.expires_at::text
  );
end $$;

do $$
declare
  v_base_id  uuid;
  v_surge_id uuid;
  v_base     public.quotes%rowtype;
  v_surge    public.quotes%rowtype;
  v_snap     jsonb;
  v_at       timestamptz := date_trunc('day', now()) + interval '11 hours';
  v_ok       boolean := false;
  v_error    text;
begin
  delete from public.surge_multipliers where id = '7e000000-0000-4000-8000-000000000001';

  begin
    v_base_id := public.quote_calculate_and_persist(
      'c0000000-0000-4000-8000-000000000003',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
      'Kariakoo Market',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
      'Mlimani City',
      '22000000-0000-4000-8000-000000000001',
      '25000000-0000-4000-8000-000000000001',
      300, 2, v_at, 2, 0, '{}'::uuid[], null, 8.5, 25
    );

    select * into v_base from public.quotes where id = v_base_id;

    insert into public.surge_multipliers (
      id, city_id, service_zone_id, vehicle_type_id, multiplier, reason,
      starts_at, ends_at, created_by
    ) values (
      '7e000000-0000-4000-8000-000000000001',
      '55555555-0000-4000-8000-000000000001', null,
      '22000000-0000-4000-8000-000000000001', 2.0000,
      'Verification surge', now() - interval '1 minute', now() + interval '1 hour',
      'a0000000-0000-4000-8000-000000000001'
    );

    v_surge_id := public.quote_calculate_and_persist(
      'c0000000-0000-4000-8000-000000000003',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
      'Kariakoo Market',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
      'Mlimani City',
      '22000000-0000-4000-8000-000000000001',
      '25000000-0000-4000-8000-000000000001',
      300, 2, v_at, 2, 0, '{}'::uuid[], null, 8.5, 25
    );

    select * into v_surge from public.quotes where id = v_surge_id;
    v_snap := public.quote_get_breakdown(v_surge_id);

    v_ok := v_surge.surge_multiplier = 2.0000
            and v_surge.subtotal = round(v_base.subtotal * 2, 2)
            and (v_snap #>> '{surge,multiplier}')::numeric = 2.0000;

    insert into _phase4_scratch values ('surge_quote', v_surge_id);
  exception when others then
    v_error := sqlerrm;
  end;

  delete from public.surge_multipliers where id = '7e000000-0000-4000-8000-000000000001';

  insert into _phase4_verification values (
    40, 'Quote engine applies the highest active surge on top of plan rates',
    case when v_ok then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'base=' || coalesce(v_base.subtotal::text, 'null') || ', surge=' || coalesce(v_surge.subtotal::text, 'null'))
  );
end $$;

do $$
declare
  v_snap  jsonb;
  v_q     public.quotes%rowtype;
begin
  select * into v_q from public.quotes where id = (select id from _phase4_scratch where key = 'cap_quote');
  v_snap := public.quote_get_breakdown(v_q.id);

  insert into _phase4_verification values (
    41, 'quote_get_breakdown returns the immutable snapshot',
    case when v_snap = v_q.pricing_breakdown_snapshot
              and (v_snap #>> '{plan,pricing_plan_version_id}') = v_q.pricing_plan_version_id::text
         then 'PASS' else 'FAIL' end,
    'snapshot bytes=' || length(v_snap::text)::text
  );
end $$;

do $$
declare
  v_qid       uuid := (select id from _phase4_scratch where key = 'promo_quote');
  v_ok        boolean := false;
  v_blocked   boolean := false;
  v_error     text;
begin
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000003', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    v_ok := public.quote_get_breakdown(v_qid) is not null;
  exception when others then
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    42, 'Quote owner can read their breakdown',
    case when v_ok then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'snapshot returned')
  );
end $$;

do $$
declare
  v_qid     uuid := (select id from _phase4_scratch where key = 'promo_quote');
  v_blocked boolean := false;
  v_error   text;
begin
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    perform public.quote_get_breakdown(v_qid);
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    43, 'Another customer cannot read the quote breakdown',
    case when v_blocked and v_error ilike '%not authorised%' then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'unauthorised read unexpectedly succeeded')
  );
end $$;

do $$
declare
  v_blocked boolean := false;
  v_error   text;
begin
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000003', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    perform public.quote_calculate_and_persist(
      'c0000000-0000-4000-8000-000000000001',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
      'Kariakoo Market',
      extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'),
      'Mlimani City',
      '22000000-0000-4000-8000-000000000001',
      '25000000-0000-4000-8000-000000000001',
      300, 2, null, 2, 0, '{}'::uuid[], null, 8.5, 25
    );
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    44, 'A customer cannot request a quote for another customer',
    case when v_blocked and v_error ilike '%cannot create a quote%' then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'cross-customer quote unexpectedly succeeded')
  );
end $$;

-- ----------------------------------------------------------------------------
-- 7. Operational helper workflows (service context)
-- ----------------------------------------------------------------------------
do $$
declare
  v_quote_a   uuid;
  v_quote_b   uuid;
  v_quote_c   uuid;
  v_quote_d   uuid;
  v_job_a     uuid := gen_random_uuid();
  v_job_b     uuid := gen_random_uuid();
  v_job_c     uuid := gen_random_uuid();
  v_job_d     uuid := gen_random_uuid();
  v_offer     uuid;
  v_offer_d1  uuid := gen_random_uuid();
  v_offer_d2  uuid := gen_random_uuid();
  v_status    text;
  v_driver    uuid;
  v_vehicle   uuid;
  v_count     integer;
  v_expired   integer;
  v_rule_id   uuid;
  v_fee       numeric;
  v_total     numeric;
  v_rating    numeric;
  v_blocked   boolean;
  v_error     text;
begin
  -- A: nearby search, dispatch rule, offer and decline.
  v_quote_a := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), 'Kariakoo',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), 'Mlimani',
    '22000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001',
    100, 1, now() + interval '1 hour', 2, 0, '{}'::uuid[], null, 4.0, 15
  );

  insert into public.jobs (id, quote_id, city_id, customer_id, scheduled_at)
  values (v_job_a, v_quote_a, '55555555-0000-4000-8000-000000000001',
          'c0000000-0000-4000-8000-000000000001', now() + interval '1 hour');

  select count(*), (array_agg(driver_id order by distance_km))[1]
    into v_count, v_driver
  from public.find_nearby_drivers(
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'),
    '22000000-0000-4000-8000-000000000001', 20, 10
  );

  insert into _phase4_verification values (
    45, 'find_nearby_drivers returns the available matching driver',
    case when v_count = 1 and v_driver = 'd0000000-0000-4000-8000-000000000001'
         then 'PASS' else 'FAIL' end,
    v_count || ' driver(s), first=' || coalesce(v_driver::text, 'none')
  );

  select dr.id into v_rule_id
  from public.dispatch_rule_for(
    '55555555-0000-4000-8000-000000000001',
    '22000000-0000-4000-8000-000000000001'
  ) dr;

  insert into _phase4_verification values (
    46, 'dispatch_rule_for resolves the seeded Dar rule',
    case when v_rule_id = '4d000000-0000-4000-8000-000000000001' then 'PASS' else 'FAIL' end,
    coalesce(v_rule_id::text, 'none')
  );

  v_offer := public.offer_job_to_driver(v_job_a, 'd0000000-0000-4000-8000-000000000001', 30);
  select response into v_status from public.job_offers where id = v_offer;

  insert into _phase4_verification values (
    47, 'offer_job_to_driver creates a pending offer',
    case when v_status = 'pending' then 'PASS' else 'FAIL' end,
    'response=' || coalesce(v_status, 'missing')
  );

  perform public.decline_job_offer(v_offer, 'Vehicle unavailable');
  select response into v_status from public.job_offers where id = v_offer;

  insert into _phase4_verification values (
    48, 'decline_job_offer moves a pending offer to declined',
    case when v_status = 'declined' then 'PASS' else 'FAIL' end,
    'response=' || coalesce(v_status, 'missing')
  );

  -- B: accept one offer, auto-reassign the other, assign and advance.
  v_quote_b := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), 'Kariakoo',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), 'Mlimani',
    '22000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001',
    100, 1, now() + interval '1 hour', 2, 0, '{}'::uuid[], null, 4.0, 15
  );

  insert into public.jobs (id, quote_id, city_id, customer_id, scheduled_at)
  values (v_job_b, v_quote_b, '55555555-0000-4000-8000-000000000001',
          'c0000000-0000-4000-8000-000000000001', now() + interval '1 hour');

  insert into public.job_offers (
    id, job_id, driver_id, offer_sequence, offered_at, expires_at,
    response, distance_to_pickup_km, eta_minutes, currency_code
  ) values
    (v_offer_d1, v_job_b, 'd0000000-0000-4000-8000-000000000001', 1,
     now(), now() + interval '30 seconds', 'pending', 1.0, 3, 'TZS'),
    (v_offer_d2, v_job_b, 'd0000000-0000-4000-8000-000000000002', 2,
     now(), now() + interval '30 seconds', 'pending', 5.0, 15, 'TZS');

  perform public.accept_job_offer(v_offer_d1);

  select status, driver_id, vehicle_id into v_status, v_driver, v_vehicle
  from public.jobs where id = v_job_b;

  insert into _phase4_verification values (
    49, 'accept_job_offer assigns the job and auto-reassigns competitors',
    case when v_status = 'accepted'
              and v_driver = 'd0000000-0000-4000-8000-000000000001'
              and v_vehicle = '28000000-0000-4000-8000-000000000001'
              and (select response from public.job_offers where id = v_offer_d1) = 'accepted'
              and (select response from public.job_offers where id = v_offer_d2) = 'auto_reassigned'
         then 'PASS' else 'FAIL' end,
    'status=' || coalesce(v_status, 'missing')
  );

  perform public.job_advance_status(v_job_b, 'heading_to_pickup', 'Leaving');
  perform public.job_advance_status(v_job_b, 'arrived', 'At pickup');
  perform public.job_advance_status(v_job_b, 'loading', 'Loading');
  perform public.job_advance_status(v_job_b, 'in_transit', 'Departed');
  perform public.job_advance_status(v_job_b, 'delivered', 'Delivered');
  perform public.job_advance_status(v_job_b, 'completed', 'Completed');

  select status, actual_duration_min into v_status, v_count
  from public.jobs where id = v_job_b;

  insert into _phase4_verification values (
    50, 'job_advance_status walks the legal lifecycle to completed',
    case when v_status = 'completed'
              and v_count is not null
              and (select count(*) from public.job_status_history where job_id = v_job_b) >= 7
              and (select count(*) from public.job_events where job_id = v_job_b) >= 7
         then 'PASS' else 'FAIL' end,
    'status=' || coalesce(v_status, 'missing') || ', history=' ||
      (select count(*)::text from public.job_status_history where job_id = v_job_b)
  );

  v_blocked := false;
  begin
    perform public.job_advance_status(v_job_b, 'in_transit', 'Illegal reopen');
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;

  insert into _phase4_verification values (
    51, 'Illegal status transition is rejected',
    case when v_blocked and v_error ilike '%illegal job transition%' then 'PASS' else 'FAIL' end,
    coalesce(v_error, 'illegal transition unexpectedly succeeded')
  );

  -- C: cancellation policy fee.
  v_quote_c := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000002',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2800 -6.8200)'), 'Ilala',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2300 -6.7200)'), 'Mbezi',
    '22000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001',
    100, 1, now() + interval '5 minutes', 2, 0, '{}'::uuid[], null, 4.0, 15
  );

  select total into v_total from public.quotes where id = v_quote_c;

  insert into public.jobs (id, quote_id, city_id, customer_id, scheduled_at)
  values (v_job_c, v_quote_c, '55555555-0000-4000-8000-000000000001',
          'c0000000-0000-4000-8000-000000000002', now() + interval '5 minutes');

  perform public.job_cancel(v_job_c, 'c0000000-0000-4000-8000-000000000002', 'Changed plans');

  select cancellation_fee into v_fee from public.jobs where id = v_job_c;

  insert into _phase4_verification values (
    52, 'job_cancel applies the country/role policy and records it',
    case when v_fee = round(v_total * 0.20, 2)
              and (select status from public.jobs where id = v_job_c) = 'cancelled'
              and (select fee_applied from public.job_cancellations where job_id = v_job_c) = v_fee
              and (select refund_status from public.job_cancellations where job_id = v_job_c) = 'not_applicable'
         then 'PASS' else 'FAIL' end,
    'quote=' || v_total || ', fee=' || v_fee
  );

  -- D: stale offer expiry.
  v_quote_d := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), 'Kariakoo',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), 'Mlimani',
    '22000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001',
    100, 1, now() + interval '1 hour', 2, 0, '{}'::uuid[], null, 4.0, 15
  );

  insert into public.jobs (id, quote_id, city_id, customer_id, scheduled_at)
  values (v_job_d, v_quote_d, '55555555-0000-4000-8000-000000000001',
          'c0000000-0000-4000-8000-000000000001', now() + interval '1 hour');

  insert into public.job_offers (
    id, job_id, driver_id, offer_sequence, offered_at, expires_at,
    response, distance_to_pickup_km, eta_minutes, currency_code
  ) values (
    gen_random_uuid(), v_job_d, 'd0000000-0000-4000-8000-000000000001', 1,
    now() - interval '2 minutes', now() - interval '1 minute',
    'pending', 1.0, 3, 'TZS'
  );

  v_expired := public.expire_stale_offers();

  insert into _phase4_verification values (
    53, 'expire_stale_offers marks overdue pending offers',
    case when v_expired >= 1
              and (select response from public.job_offers where job_id = v_job_d) = 'expired'
         then 'PASS' else 'FAIL' end,
    v_expired || ' expired'
  );

  perform public.recompute_driver_rating('d0000000-0000-4000-8000-000000000001');
  select rating into v_rating from public.drivers where id = 'd0000000-0000-4000-8000-000000000001';

  insert into _phase4_verification values (
    54, 'recompute_driver_rating aggregates recent driver ratings',
    case when v_rating = 4.50 then 'PASS' else 'FAIL' end,
    'rating=' || coalesce(v_rating::text, 'null')
  );
exception when others then
  insert into _phase4_verification values (45, 'Phase 4 helper workflow', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 8. Immutability and append-only enforcement
-- ----------------------------------------------------------------------------
do $$
declare
  v_blocked boolean;
  v_error   text;
  v_ok      boolean := true;
  v_notes   text := '';
begin
  v_blocked := false;
  begin
    update public.quotes
       set total = 1.00
     where id = '4e000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%append-only%') then
    v_ok := false;
    v_notes := v_notes || ' quote-update;';
  end if;

  v_blocked := false;
  begin
    delete from public.quotes
     where id = '4e000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%append-only%') then
    v_ok := false;
    v_notes := v_notes || ' quote-delete;';
  end if;

  v_blocked := false;
  begin
    update public.job_events
       set event_type = 'note'
     where id = (select min(id) from public.job_events where job_id = '4f000000-0000-4000-8000-000000000001');
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%append-only%') then
    v_ok := false;
    v_notes := v_notes || ' event-update;';
  end if;

  v_blocked := false;
  begin
    update public.job_offers
       set distance_to_pickup_km = 99.00
     where id = '5f000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%immutable%') then
    v_ok := false;
    v_notes := v_notes || ' offer-terms-update;';
  end if;

  v_blocked := false;
  begin
    delete from public.job_offers
     where id = '5f000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%append-only%') then
    v_ok := false;
    v_notes := v_notes || ' offer-delete;';
  end if;

  v_blocked := false;
  begin
    update public.driver_locations
       set location = extensions.ST_GeogFromText('SRID=4326;POINT(39.0000 -7.0000)')
     where driver_id = 'd0000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := true;
    v_error := sqlerrm;
  end;
  if not (v_blocked and v_error ilike '%location is immutable%') then
    v_ok := false;
    v_notes := v_notes || ' location-update;';
  end if;

  insert into _phase4_verification values (
    55, 'Append-only and partition-key triggers block mutations',
    case when v_ok then 'PASS' else 'FAIL' end,
    case when v_ok then 'quotes/events/offers/locations protected'
         else 'unexpected success:' || v_notes end
  );
end $$;

-- ----------------------------------------------------------------------------
-- 9. RLS behaviour with mocked authenticated callers
-- ----------------------------------------------------------------------------
do $$
declare
  v_quote          uuid;
  v_expected       numeric;
  v_job            uuid := gen_random_uuid();
  v_j1             integer;
  v_j2             integer;
  v_q1             integer;
  v_q2             integer;
  v_inserted       boolean := false;
  v_update_blocked boolean := false;
  v_delete_blocked boolean := false;
  v_advance_blocked boolean := false;
  v_status         text;
  v_final          numeric;
  v_error          text;
begin
  v_quote := public.quote_calculate_and_persist(
    'c0000000-0000-4000-8000-000000000001',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2700 -6.8180)'), 'Kariakoo',
    extensions.ST_GeogFromText('SRID=4326;POINT(39.2250 -6.7750)'), 'Mlimani',
    '22000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001',
    100, 1, now() + interval '1 hour', 2, 0, '{}'::uuid[], null, 3.0, 10
  );
  select total into v_expected from public.quotes where id = v_quote;

  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  select count(*) into v_j1 from public.jobs where id = '4f000000-0000-4000-8000-000000000001';
  select count(*) into v_j2 from public.jobs where id = '4f000000-0000-4000-8000-000000000002';
  select count(*) into v_q1 from public.quotes where id = '4e000000-0000-4000-8000-000000000001';
  select count(*) into v_q2 from public.quotes where id = '4e000000-0000-4000-8000-000000000002';

  begin
    insert into public.jobs (id, quote_id) values (v_job, v_quote);
    v_inserted := true;
    select status, final_amount into v_status, v_final
    from public.jobs where id = v_job;
  exception when others then
    v_error := sqlerrm;
  end;

  begin
    update public.jobs set notes = 'client update probe' where id = v_job;
  exception when others then
    v_update_blocked := true;
    v_error := sqlerrm;
  end;

  begin
    delete from public.jobs where id = v_job;
  exception when others then
    v_delete_blocked := true;
    v_error := sqlerrm;
  end;

  begin
    perform public.job_advance_status(v_job, 'matched', 'customer probe');
  exception when others then
    v_advance_blocked := true;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    56, 'RLS: customer sees only their own jobs',
    case when v_j1 = 1 and v_j2 = 0 then 'PASS' else 'FAIL' end,
    'own=' || v_j1 || ', other=' || v_j2
  );

  insert into _phase4_verification values (
    57, 'RLS: customer sees only their own quotes',
    case when v_q1 = 1 and v_q2 = 0 then 'PASS' else 'FAIL' end,
    'own=' || v_q1 || ', other=' || v_q2
  );

  insert into _phase4_verification values (
    58, 'RLS: customer can create the initial requested job from their quote',
    case when v_inserted and v_status = 'requested' and v_final = v_expected
         then 'PASS' else 'FAIL' end,
    'inserted=' || v_inserted::text || ', status=' || coalesce(v_status, 'missing')
    || ', final=' || coalesce(v_final::text, 'null')
  );

  insert into _phase4_verification values (
    59, 'RLS: customer cannot UPDATE/DELETE jobs or advance status',
    case when v_update_blocked and v_delete_blocked and v_advance_blocked
         then 'PASS' else 'FAIL' end,
    'update=' || v_update_blocked::text || ', delete=' || v_delete_blocked::text
    || ', advance=' || v_advance_blocked::text
  );
exception when others then
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  insert into _phase4_verification values (56, 'RLS: customer job/quote visibility', 'FAIL', sqlerrm);
end $$;

do $$
declare
  v_disputes           integer;
  v_customer_messages  integer;
  v_staff_messages     integer;
  v_customer_offers    integer;
  v_driver_offers      integer;
  v_jobs               integer;
  v_driver_locations   integer;
  v_customer_locations integer;
begin
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000002', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  select count(*) into v_disputes from public.disputes where id = '6b000000-0000-4000-8000-000000000001';
  select count(*) into v_customer_messages from public.dispute_messages where dispute_id = '6b000000-0000-4000-8000-000000000001';
  select count(*) into v_customer_offers from public.job_offers where job_id = '4f000000-0000-4000-8000-000000000002';
  execute 'reset role';

  perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  select count(*) into v_jobs from public.jobs;
  select count(*) into v_staff_messages from public.dispute_messages where dispute_id = '6b000000-0000-4000-8000-000000000001';
  execute 'reset role';

  perform set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000003', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  select count(*) into v_driver_offers from public.job_offers where job_id = '4f000000-0000-4000-8000-000000000002';
  select count(*) into v_driver_locations from public.driver_locations where driver_id = 'd0000000-0000-4000-8000-000000000003';
  execute 'reset role';

  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  select count(*) into v_customer_locations from public.driver_locations;
  execute 'reset role';

  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    60, 'RLS: customer sees their own dispute',
    case when v_disputes = 1 then 'PASS' else 'FAIL' end,
    v_disputes || ' dispute(s)'
  );

  insert into _phase4_verification values (
    61, 'RLS: customer sees only external dispute messages',
    case when v_customer_messages = 2 then 'PASS' else 'FAIL' end,
    v_customer_messages || ' message(s)'
  );

  insert into _phase4_verification values (
    62, 'RLS: customer sees no driver offers',
    case when v_customer_offers = 0 then 'PASS' else 'FAIL' end,
    v_customer_offers || ' offer(s)'
  );

  insert into _phase4_verification values (
    63, 'RLS: operations staff sees all jobs',
    case when v_jobs >= 3 then 'PASS' else 'FAIL' end,
    v_jobs || ' job(s)'
  );

  insert into _phase4_verification values (
    64, 'RLS: staff sees internal dispute notes',
    case when v_staff_messages = 3 then 'PASS' else 'FAIL' end,
    v_staff_messages || ' message(s)'
  );

  insert into _phase4_verification values (
    65, 'RLS: driver sees only their own offers',
    case when v_driver_offers = 1 then 'PASS' else 'FAIL' end,
    v_driver_offers || ' offer(s)'
  );

  insert into _phase4_verification values (
    66, 'RLS: driver sees their own location pings',
    case when v_driver_locations = 5 then 'PASS' else 'FAIL' end,
    v_driver_locations || ' ping(s)'
  );

  insert into _phase4_verification values (
    67, 'RLS: unrelated customer cannot see driver pings',
    case when v_customer_locations = 0 then 'PASS' else 'FAIL' end,
    v_customer_locations || ' ping(s)'
  );
end $$;

do $$
declare
  v_blocked integer := 0;
  v_error   text;
begin
  perform set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  perform set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000001', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';

  begin
    insert into public.quotes (id) values (gen_random_uuid());
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  begin
    update public.job_offers set decline_reason = 'probe'
     where id = '5f000000-0000-4000-8000-000000000001';
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  begin
    delete from public.job_events
     where id = (select min(id) from public.job_events);
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  begin
    insert into public.job_status_history (job_id, to_status)
    values ('4f000000-0000-4000-8000-000000000001', 'completed');
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  begin
    insert into public.matching_attempts (job_id, attempt_number)
    values ('4f000000-0000-4000-8000-000000000001', 99);
  exception when others then
    v_blocked := v_blocked + 1;
    v_error := sqlerrm;
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);

  insert into _phase4_verification values (
    68, 'RLS/grants block direct writes to server-owned tables',
    case when v_blocked = 5 then 'PASS' else 'FAIL' end,
    v_blocked || ' of 5 writes blocked'
  );
exception when others then
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  insert into _phase4_verification values (68, 'RLS/grants block direct writes to server-owned tables', 'FAIL', sqlerrm);
end $$;

-- ----------------------------------------------------------------------------
-- 10. Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase4_verification
order by check_no, check_name;

select
  'PHASE 4 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')::text || ' PASS, '
  || count(*) filter (where status = 'FAIL')::text || ' FAIL' as result
from _phase4_verification;



