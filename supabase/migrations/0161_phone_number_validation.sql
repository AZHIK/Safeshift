-- Phone numbers: one stored form (E.164, "+255712345678") and a check
-- against the numbering plan.
--
-- The apps validate every country in full with libphonenumber metadata. The
-- database is the backstop for any client: it normalises the common
-- Tanzanian ways of writing a number (0712..., 255712..., 712...) and
-- enforces Tanzania's plan exactly, and E.164 shape for other countries.
--
-- Tanzania (+255): nine digits after the country code.
--   mobile      6x / 7x  (Vodacom, Airtel, Yas/Tigo, Halotel, TTCL, Zantel)
--   fixed line  2x
--
-- profiles.phone is left alone: Supabase Auth owns that value and its format.

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

create or replace function private.normalize_phone(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g');
begin
  if v = '' then
    return null;
  end if;
  if v like '00%' then
    v := '+' || substr(v, 3);
  end if;
  if v like '+%' then
    return v;
  end if;
  if v ~ '^0[0-9]{9}$' then          -- national: 0712 345 678
    return '+255' || substr(v, 2);
  end if;
  if v ~ '^255[0-9]{9}$' then        -- country code without +
    return '+' || v;
  end if;
  if v ~ '^[267][0-9]{8}$' then      -- subscriber number only
    return '+255' || v;
  end if;
  return v;                          -- rejected by private.is_valid_phone
end;
$$;

create or replace function private.is_valid_phone(
  p_e164 text,
  p_mobile_only boolean default true
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_e164 is null or p_e164 !~ '^\+[1-9][0-9]{7,14}$' then false
    when p_e164 like '+255%' then
      p_e164 ~ case when p_mobile_only
                    then '^\+255[67][0-9]{8}$'
                    else '^\+255[267][0-9]{8}$' end
    else true
  end;
$$;

revoke all on function private.normalize_phone(text) from public, anon, authenticated;
revoke all on function private.is_valid_phone(text, boolean) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Trigger: normalise + validate one phone column.
--   TG_ARGV[0]  column name
--   TG_ARGV[1]  'mobile' (must receive SMS) or 'any'
--   TG_ARGV[2]  label used in the error message
-- ----------------------------------------------------------------------------

create or replace function private.enforce_phone_column()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_column text := TG_ARGV[0];
  v_mobile boolean := TG_ARGV[1] = 'mobile';
  v_label  text := coalesce(TG_ARGV[2], 'phone number');
  v_raw    text;
  v_phone  text;
begin
  v_raw := to_jsonb(new) ->> v_column;
  if v_raw is null or btrim(v_raw) = '' then
    if v_raw is not null then
      new := jsonb_populate_record(new, jsonb_build_object(v_column, null));
    end if;
    return new;
  end if;

  v_phone := private.normalize_phone(v_raw);
  if not private.is_valid_phone(v_phone, v_mobile) then
    raise exception '%',
      case when v_mobile
           then 'Enter a valid mobile ' || v_label || ' (for example 0712 345 678 or +254 712 345 678)'
           else 'Enter a valid ' || v_label || ' (for example 0712 345 678 or +254 712 345 678)'
      end
      using errcode = '22023';
  end if;

  if v_phone is distinct from v_raw then
    new := jsonb_populate_record(new, jsonb_build_object(v_column, v_phone));
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_phone_column() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Existing values: normalise what can be normalised before the checks land.
-- ----------------------------------------------------------------------------

do $$
begin
  -- Recipient numbers saved before this migration (e.g. 0766...).
  update public.jobs
     set recipient_phone = private.normalize_phone(recipient_phone)
   where recipient_phone is not null
     and recipient_phone is distinct from private.normalize_phone(recipient_phone);
exception when others then
  -- Finished jobs may be protected by immutability triggers; the constraint
  -- below is NOT VALID so old rows never block the migration.
  raise notice 'recipient phone backfill skipped: %', sqlerrm;
end;
$$;

update public.emergency_contacts
   set phone = private.normalize_phone(phone)
 where phone is distinct from private.normalize_phone(phone);
update public.fleets
   set contact_phone = private.normalize_phone(contact_phone)
 where contact_phone is distinct from private.normalize_phone(contact_phone);
update public.business_accounts
   set contact_phone = private.normalize_phone(contact_phone)
 where contact_phone is distinct from private.normalize_phone(contact_phone);
update public.job_stops
   set contact_phone = private.normalize_phone(contact_phone)
 where contact_phone is distinct from private.normalize_phone(contact_phone);

-- ----------------------------------------------------------------------------
-- Triggers (run before the CHECK constraints, so values arrive normalised).
-- ----------------------------------------------------------------------------

drop trigger if exists trg_jobs_recipient_phone on public.jobs;
create trigger trg_jobs_recipient_phone
  before insert or update of recipient_phone on public.jobs
  for each row execute function private.enforce_phone_column('recipient_phone', 'mobile', 'recipient number');

drop trigger if exists trg_emergency_contacts_phone on public.emergency_contacts;
create trigger trg_emergency_contacts_phone
  before insert or update of phone on public.emergency_contacts
  for each row execute function private.enforce_phone_column('phone', 'mobile', 'emergency contact number');

drop trigger if exists trg_fleets_contact_phone on public.fleets;
create trigger trg_fleets_contact_phone
  before insert or update of contact_phone on public.fleets
  for each row execute function private.enforce_phone_column('contact_phone', 'any', 'fleet contact number');

drop trigger if exists trg_business_accounts_contact_phone on public.business_accounts;
create trigger trg_business_accounts_contact_phone
  before insert or update of contact_phone on public.business_accounts
  for each row execute function private.enforce_phone_column('contact_phone', 'any', 'business contact number');

drop trigger if exists trg_job_stops_contact_phone on public.job_stops;
create trigger trg_job_stops_contact_phone
  before insert or update of contact_phone on public.job_stops
  for each row execute function private.enforce_phone_column('contact_phone', 'any', 'stop contact number');

-- ----------------------------------------------------------------------------
-- Stored form: E.164 everywhere.
-- ----------------------------------------------------------------------------

alter table public.jobs drop constraint if exists jobs_recipient_phone_check;
alter table public.jobs
  add constraint jobs_recipient_phone_check
  check (recipient_phone is null or recipient_phone ~ '^\+[1-9][0-9]{7,14}$') not valid;

alter table public.emergency_contacts drop constraint if exists emergency_contacts_phone_e164_check;
alter table public.emergency_contacts
  add constraint emergency_contacts_phone_e164_check
  check (phone ~ '^\+[1-9][0-9]{7,14}$') not valid;

alter table public.fleets drop constraint if exists fleets_contact_phone_e164_check;
alter table public.fleets
  add constraint fleets_contact_phone_e164_check
  check (contact_phone is null or contact_phone ~ '^\+[1-9][0-9]{7,14}$') not valid;

alter table public.business_accounts drop constraint if exists business_accounts_contact_phone_e164_check;
alter table public.business_accounts
  add constraint business_accounts_contact_phone_e164_check
  check (contact_phone is null or contact_phone ~ '^\+[1-9][0-9]{7,14}$') not valid;

alter table public.job_stops drop constraint if exists job_stops_contact_phone_e164_check;
alter table public.job_stops
  add constraint job_stops_contact_phone_e164_check
  check (contact_phone is null or contact_phone ~ '^\+[1-9][0-9]{7,14}$') not valid;

-- Validate where the existing data allows it; otherwise new rows are still
-- checked and old ones are left as they were.
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('public.jobs', 'jobs_recipient_phone_check'),
      ('public.emergency_contacts', 'emergency_contacts_phone_e164_check'),
      ('public.fleets', 'fleets_contact_phone_e164_check'),
      ('public.business_accounts', 'business_accounts_contact_phone_e164_check'),
      ('public.job_stops', 'job_stops_contact_phone_e164_check')
    ) as t(tbl, con)
  loop
    begin
      execute format('alter table %s validate constraint %I', r.tbl, r.con);
    exception when others then
      raise notice '% left NOT VALID: %', r.con, sqlerrm;
    end;
  end loop;
end;
$$;
