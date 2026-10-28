-- ============================================================================
-- 0115 — Phase 6: PDPC access logging and PII-aware RLS
-- ============================================================================
-- PostgreSQL does not support SELECT triggers. The selected compromise is an
-- RLS predicate that calls public.log_pii_select() when a non-owner reads PII.
-- This captures database-level reads. service_role reads bypass RLS and must be
-- logged explicitly by the Edge Function that performs them.
-- ============================================================================

create or replace function public.log_data_access(
  p_accessor_id uuid,
  p_target_profile_id uuid,
  p_table text,
  p_field text,
  p_target_id uuid,
  p_access_type text,
  p_purpose text,
  p_authorized boolean default true
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_accessor uuid;
  v_role public.user_role;
  v_id bigint;
begin
  v_accessor := coalesce(p_accessor_id, auth.uid());

  if v_accessor is null then
    raise exception 'accessor profile is required'
      using errcode = '22023';
  end if;

  if not (
    private.is_service_context()
    or v_accessor = auth.uid()
    or public.has_permission('manage_data_requests')
  ) then
    raise exception 'insufficient privileges to write a data access log entry'
      using errcode = '42501';
  end if;

  if p_access_type not in ('read', 'export', 'modify') then
    raise exception 'unsupported data access type: %', p_access_type
      using errcode = '22023';
  end if;

  if p_table is null or length(btrim(p_table)) = 0 then
    raise exception 'target table is required'
      using errcode = '22023';
  end if;

  v_role := public.current_user_role();

  insert into public.data_access_log (
    accessor_profile_id, accessor_role, target_profile_id,
    target_table, target_field, target_id, access_type,
    purpose, was_authorized
  ) values (
    v_accessor, v_role, p_target_profile_id,
    p_table, p_field, p_target_id, p_access_type,
    p_purpose, p_authorized
  )
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.log_data_access(uuid, uuid, text, text, uuid, text, text, boolean) is
  'Writes a PDPC data-access record. service_role reads must call this explicitly from Edge Functions.';

create or replace function public.log_pii_select(
  p_target_profile_id uuid,
  p_target_table text,
  p_target_field text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_target_profile_id is null
     or auth.uid() is null
     or p_target_profile_id = auth.uid()
     or private.is_service_context() then
    return true;
  end if;

  perform public.log_data_access(
    auth.uid(),
    p_target_profile_id,
    p_target_table,
    p_target_field,
    p_target_profile_id,
    'read',
    'rls_pii_select',
    true
  );

  return true;
end;
$$;

comment on function public.log_pii_select(uuid, text, text) is
  'RLS helper that records a non-owner PII read. This is a database-level compromise; Edge Function service_role reads must log explicitly.';

revoke all on function public.log_data_access(uuid, uuid, text, text, uuid, text, text, boolean) from public;
revoke all on function public.log_pii_select(uuid, text, text) from public;
grant execute on function public.log_data_access(uuid, uuid, text, text, uuid, text, text, boolean) to authenticated, service_role;
grant execute on function public.log_pii_select(uuid, text, text) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- profiles: log admin reads of other profiles
-- ----------------------------------------------------------------------------
drop policy if exists profiles_select_own_or_view_all on public.profiles;
create policy profiles_select_own_or_view_all on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or (
      (select public.has_permission('view_all_users'))
      and public.log_pii_select(id, 'profiles', 'phone,email,full_name')
    )
  );

-- ----------------------------------------------------------------------------
-- driver_documents: owners are not logged; verification staff are logged
-- ----------------------------------------------------------------------------
drop policy if exists driver_documents_select_own_or_verify on public.driver_documents;
create policy driver_documents_select_own_or_verify on public.driver_documents
  for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (
      (select public.has_permission('verify_driver'))
      and public.log_pii_select(driver_id, 'driver_documents', 'document_number,file_path')
    )
  );

-- ----------------------------------------------------------------------------
-- vehicle_documents: owners are not logged; verification staff are logged
-- ----------------------------------------------------------------------------
drop policy if exists vehicle_documents_select_owner_or_verify on public.vehicle_documents;
create policy vehicle_documents_select_owner_or_verify on public.vehicle_documents
  for select to authenticated
  using (
    (select public.is_vehicle_owner(vehicle_id))
    or (
      (select public.has_permission('verify_vehicle'))
      and public.log_pii_select(
        (
          select coalesce(v.owner_profile_id, v.primary_driver_id)
            from public.vehicles v
           where v.id = vehicle_documents.vehicle_id
        ),
        'vehicle_documents',
        'document_number,file_path'
      )
    )
  );

-- ----------------------------------------------------------------------------
-- driver_locations: live location is PII; log customer/staff reads
-- ----------------------------------------------------------------------------
drop policy if exists driver_locations_select_self_participant_or_staff on public.driver_locations;
create policy driver_locations_select_self_participant_or_staff on public.driver_locations
  for select to authenticated
  using (
    driver_id = (select auth.uid())
    or (
      (
        (select public.has_permission('view_all_drivers'))
        or exists (
          select 1
            from public.jobs j
           where j.id = driver_locations.job_id
             and j.status not in ('completed', 'cancelled', 'disputed')
             and j.customer_id = (select auth.uid())
        )
      )
      and public.log_pii_select(driver_id, 'driver_locations', 'location')
    )
  );
