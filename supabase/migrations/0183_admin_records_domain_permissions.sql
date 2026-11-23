-- Lets staff edit the reference tables of their own area through the
-- generic record functions (0182) without the platform-wide
-- manage_records permission: e.g. a pricing manager can add, edit and
-- delete regulated tariffs. Append-only rules from 0182 still apply.

create or replace function private.record_domain_permission(p_table text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_table
    when 'regulated_tariffs' then 'manage_regulated_tariffs'
    when 'vehicle_types' then 'manage_vehicle_catalog'
    when 'cargo_types' then 'manage_cargo_catalog'
    when 'cargo_categories' then 'manage_cargo_catalog'
    when 'promo_codes' then 'manage_promotions'
    when 'promo_code_eligibility_rules' then 'manage_promotions'
    when 'fleets' then 'manage_fleets'
    when 'fleet_members' then 'manage_fleets'
    when 'fleet_vehicles' then 'manage_fleets'
    when 'support_categories' then 'manage_tickets'
    when 'announcements' then 'send_notification'
  end;
$$;

revoke all on function private.record_domain_permission(text) from public, anon, authenticated;

create or replace function private.require_records(p_table text)
returns oid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid;
  v_domain text := private.record_domain_permission(p_table);
begin
  if not (public.has_permission('manage_records')
          or (v_domain is not null and public.has_permission(v_domain))) then
    raise exception 'manage_records permission required' using errcode = '42501';
  end if;
  v_oid := private.record_table_oid(p_table);
  if v_oid is null then
    raise exception 'unknown table %', p_table using errcode = '42P01';
  end if;
  return v_oid;
end;
$$;

revoke all on function private.require_records(text) from public, anon, authenticated;

-- Columns limited by a CHECK (col = ANY (ARRAY['a', 'b'])) report those
-- values like enum labels, so forms offer a choice instead of free text.
create or replace function public.admin_record_columns(p_table text)
returns table (
  column_name text,
  data_type text,
  is_nullable boolean,
  has_default boolean,
  is_primary_key boolean,
  is_generated boolean,
  references_table text,
  enum_values text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_pk text[] := private.record_pk_columns(v_oid);
begin
  return query
    select a.attname::text,
           format_type(a.atttypid, a.atttypmod),
           not a.attnotnull,
           a.atthasdef or a.attidentity <> '',
           a.attname::text = any (v_pk),
           a.attgenerated <> '',
           (select cf.confrelid::regclass::text
              from pg_constraint cf
             where cf.conrelid = v_oid and cf.contype = 'f' and cf.conkey = array[a.attnum]
             limit 1),
           coalesce(
             (select array_agg(e.enumlabel::text order by e.enumsortorder)
                from pg_enum e where e.enumtypid = a.atttypid),
             (select array_agg(m[1] order by ord)
                from pg_constraint ck
                cross join lateral regexp_matches(pg_get_constraintdef(ck.oid), '''((?:[^'']|'''')*)''::', 'g')
                  with ordinality as r(m, ord)
               where ck.conrelid = v_oid and ck.contype = 'c' and ck.conkey = array[a.attnum]
                 and pg_get_constraintdef(ck.oid) ~ ('\(+' || a.attname || ' = ANY \(+ARRAY\[')
                 and ck.oid = (select min(c2.oid) from pg_constraint c2
                                where c2.conrelid = v_oid and c2.contype = 'c' and c2.conkey = array[a.attnum]
                                  and pg_get_constraintdef(c2.oid) ~ ('\(+' || a.attname || ' = ANY \(+ARRAY\[')))
           )
    from pg_attribute a
    where a.attrelid = v_oid and a.attnum > 0 and not a.attisdropped
    order by a.attnum;
end;
$$;
