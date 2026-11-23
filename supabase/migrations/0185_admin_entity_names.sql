-- Names for the records console screens point at (a dispute's job, who
-- raised it, a request's requester...), for any console staff member who
-- has passed the second factor. Fleet owners only see their own fleet's
-- screens, so they are excluded. Only the short name of each row is
-- returned (see private.record_label_sql, migration 0184).

create or replace function public.admin_entity_names(p_table text, p_ids text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.admin_console_role();
  v_oid oid;
  v_pk text[];
  v_type text;
begin
  if v_role is null or v_role = 'fleet_owner' or not private.second_factor_verified() then
    raise exception 'console staff access required' using errcode = '42501';
  end if;
  v_oid := private.record_table_oid(p_table);
  if v_oid is null then
    raise exception 'unknown table %', p_table using errcode = '42P01';
  end if;
  v_pk := private.record_pk_columns(v_oid);
  if cardinality(v_pk) <> 1 then
    return '{}'::jsonb;
  end if;
  select format_type(a.atttypid, a.atttypmod) into v_type
  from pg_attribute a where a.attrelid = v_oid and a.attname = v_pk[1];
  return private.record_labels_for(v_oid, v_pk[1], v_type, p_ids);
end;
$$;

revoke all on function public.admin_entity_names(text, text[]) from public, anon;
grant execute on function public.admin_entity_names(text, text[]) to authenticated;
