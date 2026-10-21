-- ============================================================================
-- SafeShift — Phase 3 / Migration 0047
-- Immutability and overlap-prevention triggers.
--
-- 1. Published pricing versions and every row that belongs to them are
--    append-only. The single allowed in-place transition is the one performed
--    by publish_pricing_plan_version(): close the previous version and point
--    it at its successor.
-- 2. Legal tariff bands and tier tables may not overlap inside their scope.
-- 3. Non-stacking time windows may not overlap.
--
-- The immutability functions run SECURITY INVOKER so current_user reflects the
-- actual caller (the publish function sets a transaction-local context flag).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Published-version immutability
-- ----------------------------------------------------------------------------
create or replace function private.enforce_published_immutability()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_published timestamptz;
  v_version_id uuid;
  v_is_service boolean;
  v_publishing boolean;
begin
  v_is_service := current_user in ('postgres', 'supabase_admin', 'service_role')
                  or coalesce(auth.role(), '') = 'service_role';
  v_publishing := coalesce(current_setting('safeshift.publish_context', true), '') = 'on';

  if tg_table_name = 'pricing_plan_versions' then
    if tg_op = 'DELETE' then
      if old.published_at is not null and not v_is_service then
        raise exception 'published pricing plan version % cannot be deleted', old.id
          using errcode = '42501';
      end if;
      return old;
    end if;

    -- Draft versions are fully editable.
    if old.published_at is null then
      return new;
    end if;

    if v_is_service then
      return new;
    end if;

    -- The publish routine may close a published version exactly once, and only
    -- while pointing it at its published successor.
    if v_publishing
       and old.superseded_by_version_id is null
       and new.superseded_by_version_id is not null
       and new.effective_to is not null
       and new.id = old.id
       and new.pricing_plan_id = old.pricing_plan_id
       and new.version_number = old.version_number
       and new.currency_code = old.currency_code
       and new.effective_from = old.effective_from
       and new.published_at = old.published_at
       and new.published_by is not distinct from old.published_by
       and new.regulated_tariff_id is not distinct from old.regulated_tariff_id
       and new.notes is not distinct from old.notes
       and new.created_at = old.created_at
    then
      return new;
    end if;

    raise exception 'published pricing plan version % is immutable', old.id
      using errcode = '42501';
  end if;

  -- Child tables: every Phase 3 version-bound table carries
  -- pricing_plan_version_id.
  v_version_id := coalesce(
    (to_jsonb(new) ->> 'pricing_plan_version_id')::uuid,
    (to_jsonb(old) ->> 'pricing_plan_version_id')::uuid
  );

  select v.published_at into v_published
  from public.pricing_plan_versions v
  where v.id = v_version_id;

  if v_published is not null and not v_is_service then
    raise exception '% rows of published version % are immutable', tg_table_name, v_version_id
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

comment on function private.enforce_published_immutability() is
  'Blocks UPDATE/DELETE on published pricing versions and their child rows; allows only the atomic supersede transition from publish_pricing_plan_version().';

do $$
declare
  v_table text;
  v_tables text[] := array[
    'pricing_plan_versions',
    'pricing_plan_zones',
    'pricing_plan_vehicle_types',
    'pricing_plan_base_rates',
    'pricing_distance_tiers',
    'pricing_weight_tiers',
    'pricing_volume_tiers',
    'pricing_cargo_surcharges',
    'pricing_equipment_surcharges',
    'pricing_time_multipliers',
    'pricing_zone_multipliers'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'create trigger %I before update or delete on public.%I for each row execute function private.enforce_published_immutability()',
      'trg_' || v_table || '_immutable',
      v_table
    );
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 2. Regulated tariff band overlap (same tariff + band_type)
-- ----------------------------------------------------------------------------
create or replace function private.prevent_regulated_band_overlap()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.regulated_tariff_bands b
    where b.regulated_tariff_id = new.regulated_tariff_id
      and b.band_type = new.band_type
      and b.id <> new.id
      and new.min_value < coalesce(b.max_value, 'infinity'::numeric)
      and coalesce(new.max_value, 'infinity'::numeric) > b.min_value
  ) then
    raise exception 'regulated tariff % has an overlapping % band [%, %]',
      new.regulated_tariff_id, new.band_type, new.min_value, new.max_value
      using errcode = '23514';
  end if;
  return new;
end;
$$;

comment on function private.prevent_regulated_band_overlap() is
  'Rejects overlapping bands of the same band_type inside one regulated tariff.';

create trigger trg_regulated_tariff_bands_no_overlap
  before insert or update on public.regulated_tariff_bands
  for each row execute function private.prevent_regulated_band_overlap();

-- ----------------------------------------------------------------------------
-- 3. Distance, weight and volume tier overlap
-- ----------------------------------------------------------------------------
create or replace function private.prevent_distance_tier_overlap()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.pricing_distance_tiers t
    where t.pricing_plan_version_id = new.pricing_plan_version_id
      and t.id <> new.id
      and new.min_km < coalesce(t.max_km, 'infinity'::numeric)
      and coalesce(new.max_km, 'infinity'::numeric) > t.min_km
  ) then
    raise exception 'pricing version % has an overlapping distance tier [%, %]',
      new.pricing_plan_version_id, new.min_km, new.max_km
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger trg_pricing_distance_tiers_no_overlap
  before insert or update on public.pricing_distance_tiers
  for each row execute function private.prevent_distance_tier_overlap();

create or replace function private.prevent_weight_tier_overlap()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.pricing_weight_tiers t
    where t.pricing_plan_version_id = new.pricing_plan_version_id
      and t.id <> new.id
      and new.min_kg < coalesce(t.max_kg, 'infinity'::numeric)
      and coalesce(new.max_kg, 'infinity'::numeric) > t.min_kg
  ) then
    raise exception 'pricing version % has an overlapping weight tier [%, %]',
      new.pricing_plan_version_id, new.min_kg, new.max_kg
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger trg_pricing_weight_tiers_no_overlap
  before insert or update on public.pricing_weight_tiers
  for each row execute function private.prevent_weight_tier_overlap();

create or replace function private.prevent_volume_tier_overlap()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.pricing_volume_tiers t
    where t.pricing_plan_version_id = new.pricing_plan_version_id
      and t.id <> new.id
      and new.min_m3 < coalesce(t.max_m3, 'infinity'::numeric)
      and coalesce(new.max_m3, 'infinity'::numeric) > t.min_m3
  ) then
    raise exception 'pricing version % has an overlapping volume tier [%, %]',
      new.pricing_plan_version_id, new.min_m3, new.max_m3
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger trg_pricing_volume_tiers_no_overlap
  before insert or update on public.pricing_volume_tiers
  for each row execute function private.prevent_volume_tier_overlap();

-- ----------------------------------------------------------------------------
-- 4. Non-stacking time-window overlap (overnight aware)
-- ----------------------------------------------------------------------------
create or replace function private.time_segments_overlap(
  a_start numeric, a_end numeric, b_start numeric, b_end numeric
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select a_start < b_end and b_start < a_end;
$$;

comment on function private.time_segments_overlap(numeric, numeric, numeric, numeric) is
  'Half-open interval overlap test [a_start, a_end) vs [b_start, b_end), in seconds since midnight.';

create or replace function private.time_windows_overlap(
  p_days_a smallint[], p_start_a time, p_end_a time,
  p_days_b smallint[], p_start_b time, p_end_b time
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sa numeric := extract(epoch from p_start_a);
  v_ea numeric := extract(epoch from p_end_a);
  v_sb numeric := extract(epoch from p_start_b);
  v_eb numeric := extract(epoch from p_end_b);
  v_day_overlap boolean;
begin
  select exists (
    select 1
    from unnest(p_days_a) da
    join unnest(p_days_b) db on db = da
  ) into v_day_overlap;

  if not v_day_overlap then
    return false;
  end if;

  -- Normalise overnight windows into up to two segments.
  return
    (v_sa < v_ea and v_sb < v_eb
      and private.time_segments_overlap(v_sa, v_ea, v_sb, v_eb))
    or (v_sa < v_ea and v_sb >= v_eb
      and (private.time_segments_overlap(v_sa, v_ea, v_sb, 86400)
        or private.time_segments_overlap(v_sa, v_ea, 0, v_eb)))
    or (v_sa >= v_ea and v_sb < v_eb
      and (private.time_segments_overlap(v_sa, 86400, v_sb, v_eb)
        or private.time_segments_overlap(0, v_ea, v_sb, v_eb)))
    or (v_sa >= v_ea and v_sb >= v_eb
      and (private.time_segments_overlap(v_sa, 86400, v_sb, 86400)
        or private.time_segments_overlap(v_sa, 86400, 0, v_eb)
        or private.time_segments_overlap(0, v_ea, v_sb, 86400)
        or private.time_segments_overlap(0, v_ea, 0, v_eb)));
end;
$$;

comment on function private.time_windows_overlap(smallint[], time, time, smallint[], time, time) is
  'True when two day-of-week sets and time windows intersect, treating end_time < start_time as an overnight window.';

create or replace function private.prevent_time_multiplier_overlap()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_existing record;
begin
  -- Stacking windows are allowed to overlap by design.
  if new.stacks then
    return new;
  end if;

  for v_existing in
    select t.id, t.days_of_week, t.start_time, t.end_time
    from public.pricing_time_multipliers t
    where t.pricing_plan_version_id = new.pricing_plan_version_id
      and t.id <> new.id
      and not t.stacks
  loop
    if private.time_windows_overlap(
      new.days_of_week, new.start_time, new.end_time,
      v_existing.days_of_week, v_existing.start_time, v_existing.end_time
    ) then
      raise exception 'pricing version % has overlapping non-stacking time windows (existing multiplier %)',
        new.pricing_plan_version_id, v_existing.id
        using errcode = '23514';
    end if;
  end loop;

  return new;
end;
$$;

create trigger trg_pricing_time_multipliers_no_overlap
  before insert or update on public.pricing_time_multipliers
  for each row execute function private.prevent_time_multiplier_overlap();

-- ----------------------------------------------------------------------------
-- 5. Audit integration for the pricing lifecycle
-- ----------------------------------------------------------------------------
create trigger trg_pricing_plan_versions_audit
  after insert or update or delete on public.pricing_plan_versions
  for each row execute function private.audit_trigger();

create trigger trg_promo_codes_audit
  after insert or update or delete on public.promo_codes
  for each row execute function private.audit_trigger();
