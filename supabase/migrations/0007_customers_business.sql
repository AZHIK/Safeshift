-- ============================================================================
-- SafeShift — Phase 1 / Migration 0007
-- Customers, business accounts and business membership.
--
-- customers.preferred_payment_method_id has NO foreign key yet: it targets
-- public.payment_methods, created in Phase 5.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.customers
-- ----------------------------------------------------------------------------
create table public.customers (
  id                        uuid primary key references public.profiles (id) on delete cascade,
  -- FK will be added in Phase 5 (targets public.payment_methods).
  preferred_payment_method_id uuid,
  default_address_id        uuid references public.addresses (id) on delete set null,
  total_jobs                integer not null default 0,
  total_spent               numeric(14, 2) not null default 0,
  rating                    numeric(3, 2) default 5.00,
  is_flagged                boolean not null default false,
  flagged_reason            text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  constraint customers_total_jobs_check check (total_jobs >= 0),
  constraint customers_total_spent_check check (total_spent >= 0),
  constraint customers_rating_check check (rating is null or rating between 0 and 5)
);

comment on table public.customers is
  'Customer-specific state and aggregates. Server-maintained counters are protected by a trigger in migration 0014.';

comment on column public.customers.preferred_payment_method_id is
  'FK will be added in Phase 5 (references public.payment_methods.id).';

-- ----------------------------------------------------------------------------
-- public.business_accounts
-- ----------------------------------------------------------------------------
create table public.business_accounts (
  id                  uuid primary key default gen_random_uuid(),
  country_id          uuid not null references public.countries (id),
  city_id             uuid references public.cities (id),
  legal_name          text not null,
  trading_name        text,
  registration_number text,
  tax_id              text,
  industry            text,
  contact_email       text,
  contact_phone       text,
  billing_address_id  uuid references public.addresses (id) on delete set null,
  credit_limit        numeric(14, 2) not null default 0,
  current_balance     numeric(14, 2) not null default 0,
  payment_terms_days  integer not null default 0,
  is_active           boolean not null default true,
  verified_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint business_accounts_credit_limit_check check (credit_limit >= 0),
  constraint business_accounts_payment_terms_check check (payment_terms_days >= 0)
);

comment on table public.business_accounts is
  'Corporate accounts (BRELA-registered in the pilot market). credit_limit and verified_at are server-managed.';

comment on column public.business_accounts.registration_number is
  'Company registration number (BRELA number in the pilot market). Indexed but not globally unique across countries.';

comment on column public.business_accounts.tax_id is
  'Tax identification number (TIN in the pilot market).';

-- ----------------------------------------------------------------------------
-- public.business_members
-- ----------------------------------------------------------------------------
create table public.business_members (
  id                  uuid primary key default gen_random_uuid(),
  business_account_id uuid not null references public.business_accounts (id) on delete cascade,
  profile_id          uuid not null references public.profiles (id) on delete cascade,
  role                text not null,
  invited_at          timestamptz,
  accepted_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint business_members_account_profile_key unique (business_account_id, profile_id),
  constraint business_members_role_check
    check (role in ('owner', 'admin', 'booker', 'viewer'))
);

comment on table public.business_members is
  'Membership and role within a business account. Bookers create jobs; viewers only read.';

-- ----------------------------------------------------------------------------
-- Bootstrap: the first member of a business account is automatically its owner.
-- ----------------------------------------------------------------------------
-- business_accounts has no created_by column by design, so the creator is
-- identified by the authenticated request. Runs as SECURITY DEFINER because the
-- inserting client has no INSERT policy on business_members yet (there is no
-- owner to check against until this row exists).
create or replace function private.attach_business_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();

  if v_actor is not null
     and exists (select 1 from public.profiles p where p.id = v_actor)
     and not exists (
       select 1 from public.business_members bm
        where bm.business_account_id = new.id
     )
  then
    insert into public.business_members (business_account_id, profile_id, role, accepted_at)
    values (new.id, v_actor, 'owner', now())
    on conflict (business_account_id, profile_id) do nothing;
  end if;

  return new;
end;
$$;

create trigger trg_business_accounts_attach_owner
  after insert on public.business_accounts
  for each row execute function private.attach_business_owner();

comment on function private.attach_business_owner() is
  'Gives the creating profile the owner membership on a newly inserted business account.';
