-- ============================================================================
-- SafeShift — Phase 11 / Migration 0138
-- Admin console: one driver, in full.
--
-- The drivers table in the console is a queue: verification state, risk tier,
-- and lifetime numbers. Opening a row has to show the person behind it — the
-- profile, the licence, the vehicles, the uploaded documents, and the
-- verification requests a reviewer is being asked to decide.
--
-- The console cannot assemble that with plain PostgREST reads:
--
--   * public.driver_documents and public.vehicle_documents are PII-logged by
--     their SELECT policies (migration 0115). A page render is a GET, and
--     PostgREST runs GETs in a read-only transaction, so the log write the
--     policy performs aborts the read.
--   * public.verification_requests is scoped to reviewers by RLS, so a staff
--     member who may view drivers but not decide them would see nothing.
--
-- This migration adds one permission-checked, SECURITY DEFINER function that
-- reads the whole graph and writes the same PDPC access-log rows explicitly.
-- It returns JSON, so document paths only leave the database for callers that
-- hold the permission to review them.
--
-- Storage objects stay private: the console turns a returned path into a
-- short-lived signed URL through the storage API, which applies the bucket
-- policies from migration 0122 as the signed-in administrator.
-- ============================================================================

create or replace function public.admin_driver_detail(p_driver_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor              uuid := auth.uid();
  v_can_review_driver  boolean;
  v_can_review_vehicle boolean;
  v_driver             public.drivers%rowtype;
  v_profile            jsonb;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_permission('view_all_drivers')
    or public.has_permission('verify_driver')
  ) then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  select * into v_driver
    from public.drivers
   where id = p_driver_id;

  if not found then
    raise exception 'driver % not found', p_driver_id using errcode = 'P0002';
  end if;

  v_can_review_driver  := public.has_permission('verify_driver');
  v_can_review_vehicle := public.has_permission('verify_vehicle');

  -- The same explicit access-log rows the RLS policies write for a direct
  -- read. Nothing else in this function needs it: the payload is assembled
  -- from fixed joins and every document path is gated below.
  perform public.log_pii_select(v_driver.id, 'profiles', 'phone,email,full_name');
  if v_can_review_driver then
    perform public.log_pii_select(v_driver.id, 'driver_documents', 'document_number,file_path');
  end if;

  select jsonb_build_object(
           'id', p.id,
           'full_name', p.full_name,
           'display_name', p.display_name,
           'phone', p.phone,
           'email', p.email,
           'avatar_url', p.avatar_url,
           'primary_role', p.primary_role,
           'is_active', p.is_active,
           'phone_verified', p.phone_verified,
           'email_verified', p.email_verified,
           'preferred_language', lang.name,
           'default_country', ctry.name,
           'last_login_at', p.last_login_at,
           'terms_accepted_at', p.terms_accepted_at,
           'privacy_accepted_at', p.privacy_accepted_at,
           'created_at', p.created_at
         )
    into v_profile
    from public.profiles p
    left join public.languages lang on lang.id = p.preferred_language_id
    left join public.countries ctry on ctry.id = p.default_country_id
   where p.id = p_driver_id;

  return jsonb_build_object(
    'profile', coalesce(v_profile, jsonb_build_object('id', p_driver_id)),

    'driver', jsonb_build_object(
      'id', v_driver.id,
      'country_id', v_driver.country_id,
      'country_name', (select c.name from public.countries c where c.id = v_driver.country_id),
      'home_city_id', v_driver.home_city_id,
      'home_city_name', (select ci.name from public.cities ci where ci.id = v_driver.home_city_id),
      'licence_number', v_driver.licence_number,
      'licence_expiry', v_driver.licence_expiry,
      'licence_country_name', (select c.name from public.countries c where c.id = v_driver.licence_country_id),
      'verification_status', v_driver.verification_status,
      'risk_tier', v_driver.risk_tier,
      'rating', v_driver.rating,
      'total_trips', v_driver.total_trips,
      'total_earnings', v_driver.total_earnings,
      'is_available', v_driver.is_available,
      'current_location', case
        when v_driver.current_location is null then null
        else extensions.ST_AsGeoJSON(v_driver.current_location)::jsonb
      end,
      'location_updated_at', v_driver.location_updated_at,
      'verified_at', v_driver.verified_at,
      're_verification_due_at', v_driver.re_verification_due_at,
      'created_at', v_driver.created_at
    ),

    -- Driver documents are licence and identity papers: only a reviewer with
    -- verify_driver sees them, which is the same gate the RLS policy applies.
    'driver_documents', case when v_can_review_driver then (
      select coalesce(jsonb_agg(doc), '[]'::jsonb)
      from (
        select jsonb_build_object(
                 'id', dd.id,
                 'document_code', dt.code,
                 'document_name', dt.name,
                 'document_number', dd.document_number,
                 'issued_at', dd.issued_at,
                 'expires_at', dd.expires_at,
                 'file_path', dd.file_path,
                 'file_mime_type', dd.file_mime_type,
                 'file_size_bytes', dd.file_size_bytes,
                 'verification_status', dd.verification_status,
                 'rejection_reason', dd.rejection_reason,
                 'is_current', dd.is_current,
                 'created_at', dd.created_at
               ) as doc
          from public.driver_documents dd
          join public.document_types dt on dt.id = dd.document_type_id
         where dd.driver_id = p_driver_id
         order by dd.created_at desc
      ) documents
    ) else '[]'::jsonb end,

    'vehicles', (
      select coalesce(jsonb_agg(vehicle), '[]'::jsonb)
      from (
        select jsonb_build_object(
                 'id', v.id,
                 'registration_number', v.registration_number,
                 'vehicle_type_name', vt.name,
                 'vehicle_type_code', vt.code,
                 'make', mk.name,
                 'model', md.name,
                 'year', v.year,
                 'color', v.color,
                 'capacity_kg', v.capacity_kg,
                 'verification_status', v.verification_status,
                 'is_active', v.is_active,
                 'home_city_name', (select ci.name from public.cities ci where ci.id = v.home_city_id),
                 'photo_urls', v.photo_urls,
                 'created_at', v.created_at,
                 'documents', case when v_can_review_vehicle then (
                   select coalesce(jsonb_agg(doc), '[]'::jsonb)
                   from (
                     select jsonb_build_object(
                              'id', vd.id,
                              'document_code', dt.code,
                              'document_name', dt.name,
                              'document_number', vd.document_number,
                              'issued_at', vd.issued_at,
                              'expires_at', vd.expires_at,
                              'file_path', vd.file_path,
                              'file_mime_type', vd.file_mime_type,
                              'file_size_bytes', vd.file_size_bytes,
                              'verification_status', vd.verification_status,
                              'rejection_reason', vd.rejection_reason,
                              'is_current', vd.is_current,
                              'created_at', vd.created_at
                            ) as doc
                       from public.vehicle_documents vd
                       join public.document_types dt on dt.id = vd.document_type_id
                      where vd.vehicle_id = v.id
                      order by vd.created_at desc
                   ) documents
                 ) else '[]'::jsonb end
               ) as vehicle
          from public.vehicles v
          left join public.vehicle_types vt on vt.id = v.vehicle_type_id
          left join public.vehicle_makes mk on mk.id = v.make_id
          left join public.vehicle_models md on md.id = v.model_id
         where v.primary_driver_id = p_driver_id
            or exists (
              select 1
                from public.vehicle_assignments va
               where va.vehicle_id = v.id
                 and va.driver_id = p_driver_id
                 and va.is_active
                 and va.unassigned_at is null
            )
         order by v.created_at desc
      ) vehicles
    ),

    -- The reviewer's work queue for this person. Requests and their decision
    -- notes are only returned to the role that may decide them, mirroring the
    -- RLS policy on public.verification_requests.
    'verification_requests', (
      select coalesce(jsonb_agg(request), '[]'::jsonb)
      from (
        select jsonb_build_object(
                 'id', vr.id,
                 'request_type', vr.request_type,
                 'status', vr.status,
                 'priority', vr.priority,
                 'submitted_at', vr.submitted_at,
                 'reviewed_at', vr.reviewed_at,
                 'decided_at', vr.decided_at,
                 'decision_notes', vr.decision_notes,
                 'vehicle_id', vr.vehicle_id,
                 'vehicle_registration', (
                   select v.registration_number from public.vehicles v where v.id = vr.vehicle_id
                 )
               ) as request
          from public.verification_requests vr
         where (
             v_can_review_driver
             and vr.driver_id = p_driver_id
           )
            or (
              v_can_review_vehicle
              and vr.vehicle_id in (
                select v.id from public.vehicles v where v.primary_driver_id = p_driver_id
              )
            )
         order by vr.submitted_at desc
         limit 25
      ) requests
    ),

    'verification_history', case when v_can_review_driver then (
      select coalesce(jsonb_agg(entry), '[]'::jsonb)
      from (
        select jsonb_build_object(
                 'id', vh.id,
                 'action', vh.action,
                 'notes', vh.notes,
                 'actor_name', (
                   select coalesce(p.full_name, p.display_name)
                     from public.profiles p
                    where p.id = vh.actor_id
                 ),
                 'vehicle_id', vh.vehicle_id,
                 'created_at', vh.created_at
               ) as entry
          from public.verification_history vh
         where vh.driver_id = p_driver_id
         order by vh.created_at desc
         limit 20
      ) history
    ) else '[]'::jsonb end,

    'permissions', jsonb_build_object(
      'can_review_driver', v_can_review_driver,
      'can_review_vehicle', v_can_review_vehicle
    )
  );
end;
$$;

comment on function public.admin_driver_detail(uuid) is
  'Permission-checked driver file for the admin console: profile, driver row, vehicles, documents, and verification requests. Document payloads are only returned to reviewers; each read writes the same PDPC access-log rows as the RLS policies.';

revoke all on function public.admin_driver_detail(uuid) from public;
revoke all on function public.admin_driver_detail(uuid) from anon;
grant execute on function public.admin_driver_detail(uuid) to authenticated, service_role;
