-- Readable names for records, so the console can offer a dropdown for every
-- reference field and show names instead of ids.
--
--   admin_record_options(table, column, search, limit)
--     the choices for one reference column: {options: [{value, label}], more}
--   admin_record_labels(table, values)
--     names for reference values of a table: {column: {value: label}}
--   admin_record_display(table, ids)
--     names for a table's own rows (single-column keys): {id: label}
--
-- Access follows the admin_record_* functions (manage_records, or the table's
-- own area permission). Only a short name is returned for the referenced row.

-- The SQL expression (over alias t) that names a row of a table.
create or replace function private.record_label_sql(p_oid oid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_table text := (select c.relname from pg_class c where c.oid = p_oid);
  v_schema text := (select n.nspname from pg_class c join pg_namespace n on n.oid = c.relnamespace where c.oid = p_oid);
  v_col text;
  v_person constant text := '(select coalesce(nullif(p.full_name, ''''), nullif(p.display_name, ''''), p.email, p.phone)
                               from public.profiles p where p.id = %s)';
  v_day constant text := 'to_char(%s, ''DD Mon YYYY'')';
  v_money constant text := '(%s || '' '' || to_char(%s, ''FM999,999,999,990.00''))';
begin
  if v_schema = 'auth' and v_table = 'users' then
    return 'coalesce(t.email::text, t.phone::text)';
  end if;
  if v_schema <> 'public' then
    return null;
  end if;

  if v_table like 'commission\_ledger%' then
    return format('concat_ws('' · '', %s, %s, %s)', format(v_person, 't.driver_id'),
                  format(v_money, 't.currency_code', 't.commission_amount'), format(v_day, 't.created_at'));
  end if;

  case v_table
    when 'profiles' then
      return 'coalesce(nullif(t.full_name, ''''), nullif(t.display_name, ''''), t.email, t.phone)';
    when 'drivers' then
      return format('coalesce(%s, ''Driver'')', format(v_person, 't.id'));
    when 'customers' then
      return format('coalesce(%s, ''Customer'')', format(v_person, 't.id'));
    when 'vehicles' then
      return 'concat_ws('' · '', t.registration_number,
                (select m.name from public.vehicle_makes m where m.id = t.make_id),
                (select vm.name from public.vehicle_models vm where vm.id = t.model_id))';
    when 'vehicle_models' then
      return 'concat_ws('' '', (select m.name from public.vehicle_makes m where m.id = t.make_id), t.name)';
    when 'business_accounts' then
      return 'coalesce(nullif(t.trading_name, ''''), t.legal_name)';
    when 'addresses' then
      return 'concat_ws('', '', t.line_1, t.line_2)';
    when 'jobs' then
      return format('concat_ws('' · '', %s, %s, initcap(replace(t.status::text, ''_'', '' '')))',
                    format(v_person, 't.customer_id'), format(v_day, 't.created_at'));
    when 'payments' then
      return format('concat_ws('' · '', %s, %s, %s)', format(v_person, 't.customer_id'),
                    format(v_money, 't.currency_code', 't.amount'), format(v_day, 't.created_at'));
    when 'payouts' then
      return format('concat_ws('' · '', %s, %s, %s)', format(v_person, 't.driver_id'),
                    format(v_money, 't.currency_code', 't.net_amount'), format(v_day, 't.period_start'));
    when 'payout_batches' then
      return format('concat_ws('' · '', ''Payouts '' || %s, %s, initcap(t.status))',
                    format(v_day, 't.period_start'), format(v_money, 't.currency_code', 't.total_amount'));
    when 'wallets' then
      return format('concat_ws('' · '', %s, t.currency_code)', format(v_person, 't.profile_id'));
    when 'quotes' then
      return format('concat_ws('' · '', ''Quote'', %s, %s)', format(v_money, 't.currency_code', 't.total'),
                    format(v_day, 't.created_at'));
    when 'quote_requests' then
      return format('concat_ws('' · '', concat_ws('' → '', t.pickup_address, t.destination_address), %s)',
                    format(v_day, 't.created_at'));
    when 'commission_rules' then
      return 'concat_ws('' · '', initcap(replace(t.commission_type, ''_'', '' '')), t.commission_value::text,
                (select c.name from public.cities c where c.id = t.city_id),
                (select c.name from public.countries c where c.id = t.country_id))';
    when 'pricing_plan_versions' then
      return '(select pp.name from public.pricing_plans pp where pp.id = t.pricing_plan_id) || '' v'' || t.version_number';
    when 'disputes' then
      return format('concat_ws('' · '', left(t.summary, 60), initcap(t.status), %s)', format(v_day, 't.created_at'));
    when 'incidents' then
      return format('concat_ws('' · '', initcap(replace(t.incident_type, ''_'', '' '')), initcap(t.severity), %s)',
                    format(v_day, 't.occurred_at'));
    when 'verification_requests' then
      return format('concat_ws('' · '', initcap(replace(t.request_type, ''_'', '' '')), initcap(t.status), %s)',
                    format(v_day, 't.created_at'));
    when 'ratings' then
      return format('concat_ws('' · '', t.score || '' stars'', %s, %s)', format(v_person, 't.rated_profile_id'),
                    format(v_day, 't.created_at'));
    when 'user_devices' then
      return format('concat_ws('' · '', coalesce(t.device_name, t.device_type), %s)', format(v_person, 't.profile_id'));
    when 'driver_documents' then
      return format('concat_ws('' · '', (select d.name from public.document_types d where d.id = t.document_type_id),
                       t.document_number, %s)', format(v_person, 't.driver_id'));
    when 'vehicle_documents' then
      return 'concat_ws('' · '', (select d.name from public.document_types d where d.id = t.document_type_id),
                t.document_number, (select v.registration_number from public.vehicles v where v.id = t.vehicle_id))';
    when 'chat_threads' then
      return format('concat_ws('' · '', ''Chat'', left(t.last_message_preview, 40), %s)', format(v_day, 't.created_at'));
    when 'job_stops' then
      return 'concat_ws('' · '', ''Stop '' || t.stop_sequence, t.address)';
    when 'dispute_messages', 'support_ticket_messages' then
      return 'left(t.message, 60)';
    when 'zone_pricing_overrides' then
      return 'concat_ws('' · '', (select z.name from public.service_zones z where z.id = t.service_zone_id),
                ''×'' || t.multiplier::text)';
    when 'support_tickets' then
      return 'concat_ws('' · '', t.ticket_number, t.subject)';
    when 'admin_role_definitions' then
      return 'coalesce(t.label, t.role_name)';
    when 'cities' then
      return 'concat_ws('', '', t.name, (select r.name from public.regions r where r.id = t.region_id))';
    else
      null;
  end case;

  -- Otherwise: the first naming column the table has.
  select a.attname into v_col
  from unnest(array['name', 'full_name', 'display_name', 'legal_name', 'title', 'label', 'ticket_number',
                    'invoice_number', 'registration_number', 'code', 'role_name', 'permission_key', 'subject',
                    'provider_reference', 'description']) with ordinality as w(col, ord)
  join pg_attribute a on a.attrelid = p_oid and a.attname = w.col and a.attnum > 0 and not a.attisdropped
  order by w.ord
  limit 1;
  if v_col is not null then
    return format('t.%I::text', v_col);
  end if;

  if exists (select 1 from pg_attribute a where a.attrelid = p_oid and a.attname = 'created_at' and not a.attisdropped) then
    return format('%L || '' · '' || %s', initcap(replace(v_table, '_', ' ')), format(v_day, 't.created_at'));
  end if;
  return null;
end;
$$;

revoke all on function private.record_label_sql(oid) from public, anon, authenticated;

-- The single-column foreign key of a column: (target table, target column, target column type).
create or replace function private.record_reference(p_oid oid, p_column text,
  out target oid, out target_column text, out target_type text)
language sql
stable
security definer
set search_path = ''
as $$
  select cf.confrelid, ta.attname::text, format_type(ta.atttypid, ta.atttypmod)
  from pg_constraint cf
  join pg_attribute a on a.attrelid = cf.conrelid and a.attnum = cf.conkey[1]
  join pg_attribute ta on ta.attrelid = cf.confrelid and ta.attnum = cf.confkey[1]
  where cf.conrelid = p_oid and cf.contype = 'f' and cardinality(cf.conkey) = 1 and a.attname = p_column
  limit 1;
$$;

revoke all on function private.record_reference(oid, text) from public, anon, authenticated;

-- Names for some values of a table column: {value: label}.
create or replace function private.record_labels_for(p_oid oid, p_column text, p_type text, p_values text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_expr text := private.record_label_sql(p_oid);
  v_result jsonb;
begin
  if v_expr is null or coalesce(cardinality(p_values), 0) = 0 then
    return '{}'::jsonb;
  end if;
  execute format(
    'select coalesce(jsonb_object_agg(t.%1$I::text, %2$s), ''{}'') from %3$s t
      where t.%1$I = any ($1::%4$s[]) and (%2$s) is not null',
    p_column, v_expr, p_oid::regclass, p_type)
  into v_result using p_values[1:500];
  return v_result;
end;
$$;

revoke all on function private.record_labels_for(oid, text, text, text[]) from public, anon, authenticated;

create or replace function public.admin_record_options(
  p_table text, p_column text, p_search text default null, p_limit integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_ref record;
  v_expr text;
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
  v_search text := nullif(btrim(p_search), '');
  v_rows jsonb;
begin
  select * into v_ref from private.record_reference(v_oid, p_column);
  if v_ref.target is null then
    raise exception '% is not a reference column of %', p_column, p_table using errcode = '22023';
  end if;
  v_expr := coalesce(private.record_label_sql(v_ref.target), format('t.%I::text', v_ref.target_column));
  execute format(
    'select coalesce(jsonb_agg(jsonb_build_object(''value'', v, ''label'', l) order by l), ''[]'') from (
       select t.%1$I::text v, coalesce(nullif(%2$s, ''''), t.%1$I::text) l
       from %3$s t
       where $1 is null or (%2$s) ilike $1 or t.%1$I::text = $2
       order by 2
       limit $3 + 1) s',
    v_ref.target_column, v_expr, v_ref.target::regclass)
  into v_rows
  using '%' || replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_') || '%', v_search, v_limit;
  return jsonb_build_object(
    'options', coalesce((select jsonb_agg(e order by o) from jsonb_array_elements(v_rows) with ordinality x(e, o)
                          where o <= v_limit), '[]'::jsonb),
    'more', jsonb_array_length(v_rows) > v_limit);
end;
$$;

-- p_values: {"column": ["value", ...]} for reference columns of p_table.
create or replace function public.admin_record_labels(p_table text, p_values jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_key text;
  v_ref record;
  v_result jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_values) <> 'object' then
    return v_result;
  end if;
  for v_key in select jsonb_object_keys(p_values) loop
    select * into v_ref from private.record_reference(v_oid, v_key);
    continue when v_ref.target is null or jsonb_typeof(p_values -> v_key) <> 'array';
    v_result := v_result || jsonb_build_object(v_key, private.record_labels_for(
      v_ref.target, v_ref.target_column, v_ref.target_type,
      array(select jsonb_array_elements_text(p_values -> v_key))));
  end loop;
  return v_result;
end;
$$;

-- Names for a table's own rows (single-column primary key): {id: label}.
create or replace function public.admin_record_display(p_table text, p_ids text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_pk text[] := private.record_pk_columns(v_oid);
  v_type text;
begin
  if cardinality(v_pk) <> 1 then
    return '{}'::jsonb;
  end if;
  select format_type(a.atttypid, a.atttypmod) into v_type
  from pg_attribute a where a.attrelid = v_oid and a.attname = v_pk[1];
  return private.record_labels_for(v_oid, v_pk[1], v_type, p_ids);
end;
$$;

revoke all on function public.admin_record_options(text, text, text, integer) from public, anon;
revoke all on function public.admin_record_labels(text, jsonb) from public, anon;
revoke all on function public.admin_record_display(text, text[]) from public, anon;
grant execute on function public.admin_record_options(text, text, text, integer) to authenticated;
grant execute on function public.admin_record_labels(text, jsonb) to authenticated;
grant execute on function public.admin_record_display(text, text[]) to authenticated;
