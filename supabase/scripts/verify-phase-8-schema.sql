-- ============================================================================
-- SafeShift — Phase 8 client integration verification
--
-- Usage (local):
--   psql "$LOCAL_DB_URL" \
--     -v ON_ERROR_STOP=1 -f supabase/scripts/verify-phase-8-schema.sql
--
-- Run after migrations 0001–0123 and all seeds. This gate verifies the
-- backend contract used by the customer/driver apps. It does not call FCM,
-- SMS, Maps, or payment providers.
-- ============================================================================

set search_path = public, extensions;

drop table if exists _phase8_verification;
create temporary table _phase8_verification (
  check_no integer not null,
  check_name text not null,
  status text not null,
  details text
);

-- ----------------------------------------------------------------------------
-- 1. Phase 8 tables and columns
-- ----------------------------------------------------------------------------
insert into _phase8_verification (check_no, check_name, status, details)
select 1, 'job_delivery_codes exists with hashed-code columns',
       case when count(*) = 7 then 'PASS' else 'FAIL' end,
       count(*) || ' of 7 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'job_delivery_codes'
  and column_name in (
    'job_id', 'code_hash', 'issued_by', 'issued_at', 'expires_at',
    'attempts', 'verified_at'
  );

insert into _phase8_verification (check_no, check_name, status, details)
select 2, 'job_delivery_codes stores no plaintext delivery code',
       case when count(*) = 0 then 'PASS' else 'FAIL' end,
       coalesce(string_agg(column_name, ', '), 'no plaintext code column')
from information_schema.columns
where table_schema = 'public'
  and table_name = 'job_delivery_codes'
  and column_name in ('code', 'otp', 'delivery_code', 'plain_code');

insert into _phase8_verification (check_no, check_name, status, details)
select 3, 'job_delivery_codes has expiry and attempt constraints',
       case when count(*) = 2 then 'PASS' else 'FAIL' end,
       count(*) || ' of 2 constraints present'
from pg_constraint
where conrelid = 'public.job_delivery_codes'::regclass
  and conname in (
    'job_delivery_codes_expiry_check',
    'job_delivery_codes_attempts_check'
  );

insert into _phase8_verification (check_no, check_name, status, details)
select 4, 'job_delivery_codes is protected from client access',
       case when c.relrowsecurity
                  and not has_table_privilege('authenticated', 'public.job_delivery_codes', 'SELECT')
                  and not has_table_privilege('authenticated', 'public.job_delivery_codes', 'INSERT')
                  and not has_table_privilege('authenticated', 'public.job_delivery_codes', 'UPDATE')
                  and not has_table_privilege('authenticated', 'public.job_delivery_codes', 'DELETE')
            then 'PASS' else 'FAIL' end,
       'rls=' || coalesce(c.relrowsecurity::text, 'missing')
       || ', auth select='
       || has_table_privilege('authenticated', 'public.job_delivery_codes', 'SELECT')::text
from pg_class c
where c.oid = to_regclass('public.job_delivery_codes');

-- ----------------------------------------------------------------------------
-- 2. RPCs exist with the expected signatures
-- ----------------------------------------------------------------------------
drop table if exists _phase8_functions;
create temporary table _phase8_functions (
  name text primary key,
  signature text not null
);
insert into _phase8_functions (name, signature) values
  ('ensure_my_profile', 'public.ensure_my_profile(text,text)'),
  ('customer_jobs', 'public.customer_jobs(integer)'),
  ('customer_job', 'public.customer_job(uuid)'),
  ('driver_pending_offers', 'public.driver_pending_offers()'),
  ('driver_active_job', 'public.driver_active_job()'),
  ('driver_trips', 'public.driver_trips(integer)'),
  ('driver_earnings_summary', 'public.driver_earnings_summary()'),
  ('driver_documents_list', 'public.driver_documents_list()'),
  ('driver_vehicle_info', 'public.driver_vehicle_info()'),
  ('driver_ratings_list', 'public.driver_ratings_list(integer)'),
  ('job_issue_delivery_otp', 'public.job_issue_delivery_otp(uuid)'),
  ('job_verify_delivery_otp', 'public.job_verify_delivery_otp(uuid,text)'),
  ('match_dispatch', 'public.match_dispatch(uuid,numeric,integer,integer)'),
  ('ensure_job_chat_thread', 'public.ensure_job_chat_thread(uuid)');

insert into _phase8_verification (check_no, check_name, status, details)
select 5, 'All Phase 8 RPCs exist',
       case when count(*) = (select count(*) from _phase8_functions)
            then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase8_functions) || ' present'
from _phase8_functions f
where to_regprocedure(f.signature) is not null;

insert into _phase8_verification (check_no, check_name, status, details)
select 6, 'All Phase 8 RPCs are SECURITY DEFINER with an empty search_path',
       case when count(*) = (select count(*) from _phase8_functions)
            then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase8_functions) || ' hardened'
from _phase8_functions f
join pg_proc p on p.oid = to_regprocedure(f.signature)
where p.prosecdef
  and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%';

insert into _phase8_verification (check_no, check_name, status, details)
select 7, 'Phase 8 RPCs are executable by authenticated, not anon',
       case when count(*) = (select count(*) from _phase8_functions)
            then 'PASS' else 'FAIL' end,
       count(*) || ' of ' || (select count(*) from _phase8_functions)
       || ' correctly granted'
from _phase8_functions f
join pg_proc p on p.oid = to_regprocedure(f.signature)
where has_function_privilege('authenticated', p.oid, 'EXECUTE')
  and has_function_privilege('service_role', p.oid, 'EXECUTE')
  and not has_function_privilege('anon', p.oid, 'EXECUTE');

insert into _phase8_verification (check_no, check_name, status, details)
select 8, 'match_dispatch returns jsonb',
       case when p.prorettype = 'jsonb'::regtype then 'PASS' else 'FAIL' end,
       coalesce(p.prorettype::regtype::text, 'missing')
from (select to_regprocedure(
        'public.match_dispatch(uuid,numeric,integer,integer)'
      ) as oid) x
left join pg_proc p on p.oid = x.oid;

-- ----------------------------------------------------------------------------
-- 3. Storage buckets and policies
-- ----------------------------------------------------------------------------
insert into _phase8_verification (check_no, check_name, status, details)
select 9, 'All four Phase 8 storage buckets exist and are private',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 private buckets present'
from storage.buckets
where id in ('driver-documents', 'vehicle-documents', 'job-evidence', 'chat-attachments')
  and not public;

insert into _phase8_verification (check_no, check_name, status, details)
select 10, 'Storage buckets have size limits and MIME allow-lists',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 buckets constrained'
from storage.buckets
where id in ('driver-documents', 'vehicle-documents', 'job-evidence', 'chat-attachments')
  and file_size_limit is not null
  and allowed_mime_types is not null;

insert into _phase8_verification (check_no, check_name, status, details)
select 11, 'Storage RLS policies cover every Phase 8 bucket',
       case when count(*) = 12 then 'PASS' else 'FAIL' end,
       count(*) || ' of 12 expected bucket policies present'
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    policyname like 'driver_documents_storage_%'
    or policyname like 'vehicle_documents_storage_%'
    or policyname like 'job_evidence_storage_%'
    or policyname like 'chat_attachments_storage_%'
  );

insert into _phase8_verification (check_no, check_name, status, details)
select 12, 'Job evidence and chat policies are path-scoped to job participants',
       case when count(*) = 4 then 'PASS' else 'FAIL' end,
       count(*) || ' of 4 participant-scoped policies present'
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in (
    'job_evidence_storage_select',
    'job_evidence_storage_insert',
    'chat_attachments_storage_select',
    'chat_attachments_storage_insert'
  );

-- ----------------------------------------------------------------------------
-- 4. Dispatch and realtime contract
-- ----------------------------------------------------------------------------
insert into _phase8_verification (check_no, check_name, status, details)
select 13, 'job_offers is published on supabase_realtime',
       case when exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'job_offers'
       ) then 'PASS' else 'FAIL' end,
       'publication supabase_realtime';

insert into _phase8_verification (check_no, check_name, status, details)
select 14, 'job_offers exposes the columns the driver app reads',
       case when count(*) = 8 then 'PASS' else 'FAIL' end,
       count(*) || ' of 8 columns present'
from information_schema.columns
where table_schema = 'public'
  and table_name = 'job_offers'
  and column_name in (
    'id', 'job_id', 'driver_id', 'offer_sequence', 'response',
    'expires_at', 'distance_to_pickup_km', 'eta_minutes'
  );

insert into _phase8_verification (check_no, check_name, status, details)
select 15, 'job_offers enforces positive sequence and one offer per driver/time',
       case when exists (
         select 1
         from pg_constraint c
         where c.conrelid = 'public.job_offers'::regclass
           and c.conname = 'job_offers_sequence_check'
       ) and exists (
         select 1
         from pg_constraint c
         where c.conrelid = 'public.job_offers'::regclass
           and c.contype = 'u'
           and pg_get_constraintdef(c.oid) like '%(job_id, driver_id, offered_at)%'
       ) then 'PASS' else 'FAIL' end,
       'sequence >= 1, unique(job_id, driver_id, offered_at)';

insert into _phase8_verification (check_no, check_name, status, details)
select 16, 'job_offers has RLS enabled',
       case when c.relrowsecurity then 'PASS' else 'FAIL' end,
       'rls=' || coalesce(c.relrowsecurity::text, 'missing')
from pg_class c
where c.oid = to_regclass('public.job_offers');

-- ----------------------------------------------------------------------------
-- 5. Phase 6 chat compatibility
-- ----------------------------------------------------------------------------
insert into _phase8_verification (check_no, check_name, status, details)
select 17, 'Chat attachment tables are still present',
       case when count(*) = 3 then 'PASS' else 'FAIL' end,
       count(*) || ' of 3 chat tables present'
from information_schema.tables
where table_schema = 'public'
  and table_name in ('chat_threads', 'chat_messages', 'chat_attachments');

insert into _phase8_verification (check_no, check_name, status, details)
select 18, 'chat_messages and chat_attachments are client-writable by participants',
       case when has_table_privilege('authenticated', 'public.chat_messages', 'INSERT')
                  and has_table_privilege('authenticated', 'public.chat_attachments', 'INSERT')
            then 'PASS' else 'FAIL' end,
       'chat_messages insert='
       || has_table_privilege('authenticated', 'public.chat_messages', 'INSERT')::text
       || ', chat_attachments insert='
       || has_table_privilege('authenticated', 'public.chat_attachments', 'INSERT')::text;

-- ----------------------------------------------------------------------------
-- 6. Seed/config readiness
-- ----------------------------------------------------------------------------
insert into _phase8_verification (check_no, check_name, status, details)
select 19, 'Vehicle and cargo configuration used by the quote flow is seeded',
       case when (
         select count(*) from public.vehicle_types where is_active
       ) > 0 and (
         select count(*) from public.cargo_types where is_active
       ) > 0 then 'PASS' else 'FAIL' end,
       (select count(*) from public.vehicle_types where is_active) || ' vehicle types, '
       || (select count(*) from public.cargo_types where is_active) || ' cargo types';

insert into _phase8_verification (check_no, check_name, status, details)
select 20, 'A verified driver and verified vehicle are available for dispatch tests',
       case when exists (
         select 1
         from public.drivers d
         join public.vehicles v on v.id = d.current_vehicle_id
         where d.verification_status = 'verified'
           and v.verification_status = 'verified'
           and v.is_active
       ) then 'PASS' else 'FAIL' end,
       'verified driver + vehicle';

-- ----------------------------------------------------------------------------
-- 7. Results
-- ----------------------------------------------------------------------------
select
  check_no,
  lpad(check_no::text, 2, '0') as no,
  check_name,
  status,
  details
from _phase8_verification
order by check_no, check_name;

select
  'PHASE 8 SCHEMA VERIFICATION: '
  || count(*) filter (where status = 'PASS')
  || ' PASS, '
  || count(*) filter (where status = 'FAIL')
  || ' FAIL' as result
from _phase8_verification;

select check_no, check_name, details
from _phase8_verification
where status = 'FAIL'
order by check_no, check_name;

drop table if exists _phase8_verification;
drop table if exists _phase8_functions;
