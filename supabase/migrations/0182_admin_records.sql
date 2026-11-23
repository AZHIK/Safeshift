-- Generic record management for the admin console: view, list, create, edit
-- and delete a row in any public table, plus account deletion.
--
-- Gate: has_permission('manage_records') (super_admin; second factor
-- required like every staff permission). Every write is audited.
--
-- Financial and audit records stay append-only. Tables guarded by an
-- immutability trigger (payments, refunds, payouts, ledgers, wallets,
-- webhooks, notification/chat logs, job history, published pricing) plus
-- the money and audit tables below refuse raw writes here: these functions
-- run as the owner, which some of those triggers exempt, so raw edits would
-- bypass the rules that keep the books correct. Their dedicated console
-- workflows (refund, hold payout, pricing drafts...) remain the way to act.

insert into public.admin_permissions_catalog (permission_key, description, category)
values ('manage_records', 'View, create, edit and delete records in any table', 'platform')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
values ('super_admin', 'manage_records')
on conflict (role_name, permission_key) do nothing;

-- ----------------------------------------------------------------------------
-- Table rules
-- ----------------------------------------------------------------------------

create or replace function private.record_table_oid(p_table text)
returns oid
language sql
stable
security definer
set search_path = ''
as $$
  select c.oid
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = p_table
    and c.relkind in ('r', 'p') and not c.relispartition;
$$;

-- Why raw writes are refused for a table, or null when they are allowed.
create or replace function private.record_write_block(p_table text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_table in ('payments', 'refunds', 'payouts', 'payout_items', 'payout_batches', 'wallets',
                     'wallet_transactions', 'commission_ledger', 'promo_redemptions', 'invoices',
                     'invoice_line_items', 'fleet_billing_events', 'payment_webhooks')
      then 'Money records are append-only. Use the Payments, Payouts or Billing screens.'
    when p_table in ('admin_actions_log', 'data_access_log', 'notification_log', 'job_events',
                     'job_status_history', 'chat_messages', 'chat_read_receipts', 'verification_history',
                     'driver_status_history', 'incident_actions')
      then 'Audit and history records are append-only.'
    when p_table like 'pricing\_%' escape '\' or p_table in ('zone_pricing_overrides', 'zone_pricing_override_resolution')
      then 'Pricing changes go through drafts on the Pricing screen, so published prices stay intact.'
    when exists (
      select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
      where t.tgrelid = private.record_table_oid(p_table) and not t.tgisinternal
        and p.proname ilike '%immutab%')
      then 'This table is append-only.'
  end;
$$;

revoke all on function private.record_table_oid(text) from public, anon, authenticated;
revoke all on function private.record_write_block(text) from public, anon, authenticated;

create or replace function private.require_records(p_table text)
returns oid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid;
begin
  if not public.has_permission('manage_records') then
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

-- Primary-key columns of a table, in key order.
create or replace function private.record_pk_columns(p_oid oid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_agg(a.attname::text order by k.ord)
  from pg_index i
  cross join lateral unnest(i.indkey) with ordinality k(attnum, ord)
  join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k.attnum
  where i.indrelid = p_oid and i.indisprimary;
$$;

revoke all on function private.record_pk_columns(oid) from public, anon, authenticated;

-- "pk1 = $1.pk1 and pk2 = $1.pk2" against a populated record named r.
create or replace function private.record_pk_predicate(p_oid oid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select string_agg(format('t.%1$I = r.%1$I', c), ' and ')
  from unnest(private.record_pk_columns(p_oid)) c;
$$;

revoke all on function private.record_pk_predicate(oid) from public, anon, authenticated;

-- Writable columns among the given keys (exist, not generated, not dropped).
create or replace function private.record_writable_columns(p_oid oid, p_keys text[])
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(a.attname::text order by a.attnum), '{}')
  from pg_attribute a
  where a.attrelid = p_oid and a.attnum > 0 and not a.attisdropped
    and a.attgenerated = '' and a.attname::text = any (p_keys);
$$;

revoke all on function private.record_writable_columns(oid, text[]) from public, anon, authenticated;

create or replace function private.record_audit(p_table text, p_action text, p_old jsonb, p_new jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  begin
    v_id := coalesce(p_new ->> 'id', p_old ->> 'id')::uuid;
  exception when others then
    v_id := null;
  end;
  perform private.audit_admin_change(
    'admin_override', p_table, v_id,
    p_old,
    jsonb_build_object('record_action', p_action, 'table', p_table) || coalesce(p_new, '{}'::jsonb)
  );
end;
$$;

revoke all on function private.record_audit(text, text, jsonb, jsonb) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Read
-- ----------------------------------------------------------------------------

-- Every public table with its size and whether raw writes are allowed.
create or replace function public.admin_record_tables()
returns table (table_name text, approx_rows bigint, writable boolean, write_block text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('manage_records') then
    raise exception 'manage_records permission required' using errcode = '42501';
  end if;
  return query
    select c.relname::text,
           greatest(c.reltuples, 0)::bigint,
           private.record_write_block(c.relname) is null,
           private.record_write_block(c.relname)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition
    order by c.relname;
end;
$$;

-- Column metadata for building forms.
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
           (select array_agg(e.enumlabel::text order by e.enumsortorder)
              from pg_enum e where e.enumtypid = a.atttypid)
    from pg_attribute a
    where a.attrelid = v_oid and a.attnum > 0 and not a.attisdropped
    order by a.attnum;
end;
$$;

-- One page of rows. p_search matches any text-castable column.
create or replace function public.admin_record_list(
  p_table text,
  p_search text default null,
  p_order text default null,
  p_desc boolean default true,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_order text;
  v_where text := 'true';
  v_rows jsonb;
  v_total bigint;
begin
  -- Order by a real column only; default: created_at, else the primary key.
  select a.attname::text into v_order
  from pg_attribute a
  where a.attrelid = v_oid and a.attnum > 0 and not a.attisdropped
    and a.attname::text = coalesce(nullif(p_order, ''), 'created_at');
  v_order := coalesce(v_order, (private.record_pk_columns(v_oid))[1]);

  if nullif(btrim(coalesce(p_search, '')), '') is not null then
    v_where := 'to_jsonb(t)::text ilike $1';
  end if;

  execute format('select count(*) from public.%I t where %s', p_table, v_where)
    into v_total using '%' || btrim(coalesce(p_search, '')) || '%';

  execute format(
    'select coalesce(jsonb_agg(to_jsonb(t) order by t.%I %s nulls last), ''[]'') from (select * from public.%I t where %s order by t.%I %s nulls last limit %s offset %s) t',
    v_order, case when p_desc then 'desc' else 'asc' end, p_table, v_where,
    v_order, case when p_desc then 'desc' else 'asc' end,
    least(greatest(coalesce(p_limit, 50), 1), 200), greatest(coalesce(p_offset, 0), 0)
  ) into v_rows using '%' || btrim(coalesce(p_search, '')) || '%';

  return jsonb_build_object('rows', v_rows, 'total', v_total, 'order', v_order,
                            'primary_key', to_jsonb(private.record_pk_columns(v_oid)),
                            'write_block', private.record_write_block(p_table));
end;
$$;

-- One row by primary key (p_key: {"id": "..."} or every key column).
create or replace function public.admin_record_get(p_table text, p_key jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_row jsonb;
begin
  execute format(
    'select to_jsonb(t) from public.%1$I t, jsonb_populate_record(null::public.%1$I, $1) r where %2$s',
    p_table, private.record_pk_predicate(v_oid)
  ) into v_row using p_key;
  if v_row is null then
    raise exception 'record not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- ----------------------------------------------------------------------------
-- Write
-- ----------------------------------------------------------------------------

create or replace function public.admin_record_insert(p_table text, p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_block text := private.record_write_block(p_table);
  v_cols text[];
  v_row jsonb;
begin
  if v_block is not null then
    raise exception '%', v_block using errcode = '42501';
  end if;
  if jsonb_typeof(p_values) is distinct from 'object' then
    raise exception 'values must be a JSON object' using errcode = '22023';
  end if;
  v_cols := private.record_writable_columns(v_oid, array(select jsonb_object_keys(p_values)));
  if cardinality(v_cols) = 0 then
    raise exception 'no known columns in the values' using errcode = '22023';
  end if;

  execute format(
    'insert into public.%1$I as t (%2$s) select %3$s from jsonb_populate_record(null::public.%1$I, $1) r returning to_jsonb(t)',
    p_table,
    (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
    (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c)
  ) into v_row using p_values;

  perform private.record_audit(p_table, 'insert', null, v_row);
  return v_row;
end;
$$;

create or replace function public.admin_record_update(p_table text, p_key jsonb, p_values jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_block text := private.record_write_block(p_table);
  v_pk text[] := private.record_pk_columns(v_oid);
  v_cols text[];
  v_old jsonb;
  v_row jsonb;
begin
  if v_block is not null then
    raise exception '%', v_block using errcode = '42501';
  end if;
  if jsonb_typeof(p_values) is distinct from 'object' then
    raise exception 'values must be a JSON object' using errcode = '22023';
  end if;
  -- Keys identify the row; they are not edited.
  v_cols := array(select c from unnest(
    private.record_writable_columns(v_oid, array(select jsonb_object_keys(p_values)))) c
    where c <> all (v_pk));
  if cardinality(v_cols) = 0 then
    raise exception 'nothing to update' using errcode = '22023';
  end if;

  v_old := public.admin_record_get(p_table, p_key);

  execute format(
    'update public.%1$I t set (%2$s) = (select %3$s from jsonb_populate_record(null::public.%1$I, $2) v) from jsonb_populate_record(null::public.%1$I, $1) r where %4$s returning to_jsonb(t)',
    p_table,
    (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
    (select string_agg(format('v.%I', c), ', ') from unnest(v_cols) c),
    private.record_pk_predicate(v_oid)
  ) into v_row using p_key, p_values;

  perform private.record_audit(p_table, 'update', v_old, v_row);
  return v_row;
end;
$$;

-- Rows elsewhere that point at this row, as "table: count, …", or null.
-- Checks every foreign key, including ON DELETE CASCADE / SET NULL ones:
-- a generic delete must never silently wipe or orphan dependent records.
create or replace function private.record_dependents(p_oid oid, p_row jsonb)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fk record;
  v_count bigint;
  v_found text[] := '{}';
begin
  for v_fk in
    select c.conrelid::regclass::text as child,
           (select string_agg(format('d.%I', a.attname), ', ' order by k.ord)
              from unnest(c.conkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as child_cols,
           (select string_agg(format('r.%I', a.attname), ', ' order by k.ord)
              from unnest(c.confkey) with ordinality k(attnum, ord)
              join pg_attribute a on a.attrelid = c.confrelid and a.attnum = k.attnum) as parent_cols
    from pg_constraint c
    where c.contype = 'f' and c.confrelid = p_oid
  loop
    execute format(
      'select count(*) from %s d, jsonb_populate_record(null::%s, $1) r where (%s) = (%s)',
      v_fk.child, p_oid::regclass, v_fk.child_cols, v_fk.parent_cols
    ) into v_count using p_row;
    if v_count > 0 then
      v_found := v_found || format('%s: %s', replace(v_fk.child, 'public.', ''), v_count);
    end if;
  end loop;
  return nullif(array_to_string(v_found, ', '), '');
end;
$$;

revoke all on function private.record_dependents(oid, jsonb) from public, anon, authenticated;

create or replace function public.admin_record_delete(p_table text, p_key jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_oid oid := private.require_records(p_table);
  v_block text := private.record_write_block(p_table);
  v_old jsonb;
  v_dependents text;
begin
  if v_block is not null then
    raise exception '%', v_block using errcode = '42501';
  end if;
  if p_table in ('profiles', 'drivers') then
    raise exception 'delete people with the account delete action, which handles their history' using errcode = '42501';
  end if;
  v_old := public.admin_record_get(p_table, p_key);
  v_dependents := private.record_dependents(v_oid, v_old);
  if v_dependents is not null then
    raise exception 'other records still use this one (%); deactivate it instead, or remove those first', v_dependents
      using errcode = '23503';
  end if;
  begin
    execute format(
      'delete from public.%1$I t using jsonb_populate_record(null::public.%1$I, $1) r where %2$s',
      p_table, private.record_pk_predicate(v_oid)
    ) using p_key;
  exception when foreign_key_violation then
    raise exception 'other records still use this one (%); deactivate it instead, or remove those first', sqlerrm
      using errcode = '23503';
  end;
  perform private.record_audit(p_table, 'delete', v_old, null);
end;
$$;

-- ----------------------------------------------------------------------------
-- Accounts
-- ----------------------------------------------------------------------------

-- Deletes a person completely when nothing references them; otherwise erases
-- their personal data and blocks the login while keeping business records
-- (jobs, payments, tickets) intact. Returns 'deleted' or 'anonymized'.
create or replace function public.admin_delete_account(p_profile_id uuid, p_reason text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := btrim(coalesce(p_reason, ''));
  v_old public.profiles%rowtype;
  v_ref record;
  v_has_history boolean := false;
begin
  if not (public.has_permission('suspend_user') and public.has_permission('manage_records')) then
    raise exception 'suspend_user and manage_records permissions required' using errcode = '42501';
  end if;
  if length(v_reason) < 3 then
    raise exception 'a reason is required to delete an account' using errcode = '22004';
  end if;
  if p_profile_id = auth.uid() then
    raise exception 'you cannot delete your own account' using errcode = '42501';
  end if;
  if p_profile_id = '00000000-0000-4000-8000-000000000000' then
    raise exception 'the platform account cannot be deleted' using errcode = '42501';
  end if;
  select * into v_old from public.profiles where id = p_profile_id for update;
  if not found then
    raise exception 'account % not found', p_profile_id using errcode = 'P0002';
  end if;
  if exists (select 1 from public.admin_roles where profile_id = p_profile_id and is_active and revoked_at is null)
     and not public.has_permission('manage_admins') then
    raise exception 'manage_admins permission required to delete an administrator' using errcode = '42501';
  end if;
  if private.driver_active_job_count(p_profile_id) > 0 then
    raise exception 'this driver has a job in progress; release or reassign it first' using errcode = '23514';
  end if;

  -- Any restricting reference to the profile is business history.
  for v_ref in
    select c.conrelid::regclass::text as tbl, a.attname::text as col
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'public.profiles'::regclass
      and c.confdeltype in ('r', 'a') and cardinality(c.conkey) = 1
  loop
    execute format('select exists (select 1 from %s where %I = $1)', v_ref.tbl, v_ref.col)
      into v_has_history using p_profile_id;
    exit when v_has_history;
  end loop;

  if not v_has_history then
    delete from auth.users where id = p_profile_id;  -- cascades to profile and driver rows
    perform private.audit_admin_change('user_suspended', 'profile', p_profile_id,
      to_jsonb(v_old), jsonb_build_object('deleted', true, 'reason', v_reason));
    return 'deleted';
  end if;

  -- profiles_contact_present_check needs a phone or an email: use a
  -- non-deliverable placeholder that carries no personal data.
  update public.profiles
     set full_name = 'Deleted user', display_name = null, phone = null,
         email = 'deleted+' || p_profile_id::text || '@deleted.invalid',
         is_active = false, deactivated_at = now(), deactivation_reason = 'Deleted: ' || v_reason
   where id = p_profile_id;
  update public.drivers set is_available = false, verification_status = 'suspended',
         suspension_reason = 'Account deleted', suspended_at = now(), suspended_by = auth.uid()
   where id = p_profile_id;
  delete from auth.sessions where user_id = p_profile_id;
  delete from auth.identities where user_id = p_profile_id;
  update auth.users
     set email = null, phone = null, banned_until = now() + interval '100 years',
         raw_user_meta_data = '{}'::jsonb
   where id = p_profile_id;

  perform private.audit_admin_change('user_suspended', 'profile', p_profile_id,
    jsonb_build_object('full_name', v_old.full_name, 'phone', v_old.phone, 'email', v_old.email),
    jsonb_build_object('anonymized', true, 'reason', v_reason));
  return 'anonymized';
end;
$$;

revoke all on function public.admin_record_tables() from public, anon;
revoke all on function public.admin_record_columns(text) from public, anon;
revoke all on function public.admin_record_list(text, text, text, boolean, integer, integer) from public, anon;
revoke all on function public.admin_record_get(text, jsonb) from public, anon;
revoke all on function public.admin_record_insert(text, jsonb) from public, anon;
revoke all on function public.admin_record_update(text, jsonb, jsonb) from public, anon;
revoke all on function public.admin_record_delete(text, jsonb) from public, anon;
revoke all on function public.admin_delete_account(uuid, text) from public, anon;
grant execute on function public.admin_record_tables() to authenticated;
grant execute on function public.admin_record_columns(text) to authenticated;
grant execute on function public.admin_record_list(text, text, text, boolean, integer, integer) to authenticated;
grant execute on function public.admin_record_get(text, jsonb) to authenticated;
grant execute on function public.admin_record_insert(text, jsonb) to authenticated;
grant execute on function public.admin_record_update(text, jsonb, jsonb) to authenticated;
grant execute on function public.admin_record_delete(text, jsonb) to authenticated;
grant execute on function public.admin_delete_account(uuid, text) to authenticated;
