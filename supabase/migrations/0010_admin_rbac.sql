-- ============================================================================
-- SafeShift — Phase 1 / Migration 0010
-- Administration and role-based access control.
--
-- admin_roles grants a profile an administrative role, optionally scoped to a
-- country or a single city. admin_role_permissions maps roles to capabilities.
-- admin_actions_log is the queryable admin audit trail (distinct from the
-- generic private.audit_log).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- public.admin_permissions_catalog
-- ----------------------------------------------------------------------------
create table public.admin_permissions_catalog (
  id             uuid primary key default gen_random_uuid(),
  permission_key text not null unique,
  description    text not null,
  category       text,
  created_at     timestamptz not null default now()
);

comment on table public.admin_permissions_catalog is
  'Read-only catalogue of every administrative permission the platform recognises.';

comment on column public.admin_permissions_catalog.category is
  'Grouping for admin UI: operations, finance, trust_safety, pricing, support, platform, compliance.';

-- ----------------------------------------------------------------------------
-- public.admin_roles
-- ----------------------------------------------------------------------------
create table public.admin_roles (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles (id) on delete cascade,
  role_name     text not null,
  country_id    uuid references public.countries (id),
  city_id       uuid references public.cities (id),
  is_active     boolean not null default true,
  granted_by    uuid references public.profiles (id) on delete set null,
  granted_at    timestamptz not null default now(),
  expires_at    timestamptz,
  revoked_at    timestamptz,
  revoked_reason text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint admin_roles_role_name_check check (
    role_name in (
      'super_admin',
      'operations_admin',
      'verification_admin',
      'support_agent',
      'finance_admin',
      'analyst'
    )
  ),
  constraint admin_roles_expiry_check
    check (expires_at is null or expires_at > granted_at)
);

comment on table public.admin_roles is
  'Administrative role grants. country_id NULL = all countries; city_id NULL = all cities in scope.';

comment on column public.admin_roles.city_id is
  'When set, the role is scoped to a single city. Evaluated by public.has_permission(permission, city_id).';

-- ----------------------------------------------------------------------------
-- public.admin_role_permissions
-- ----------------------------------------------------------------------------
create table public.admin_role_permissions (
  id             uuid primary key default gen_random_uuid(),
  role_name      text not null,
  permission_key text not null references public.admin_permissions_catalog (permission_key)
                   on update cascade on delete cascade,
  created_at     timestamptz not null default now(),

  constraint admin_role_permissions_role_key unique (role_name, permission_key),
  constraint admin_role_permissions_role_name_check check (
    role_name in (
      'super_admin',
      'operations_admin',
      'verification_admin',
      'support_agent',
      'finance_admin',
      'analyst'
    )
  )
);

comment on table public.admin_role_permissions is
  'Maps each admin role to the permissions it grants. Read-only for clients.';

-- ----------------------------------------------------------------------------
-- public.admin_actions_log
-- ----------------------------------------------------------------------------
create table public.admin_actions_log (
  id               bigint generated always as identity primary key,
  admin_profile_id uuid not null references public.profiles (id) on delete restrict,
  admin_role       text not null,
  permission_used  text,
  action           text not null,
  entity_type      text,
  entity_id        uuid,
  old_value        jsonb,
  new_value        jsonb,
  ip_address       inet,
  user_agent       text,
  created_at       timestamptz not null default now()
);

comment on table public.admin_actions_log is
  'Queryable admin action trail (approved_driver, adjusted_price, refunded_payment, ...). Partition when this exceeds ~100 million rows.';

comment on column public.admin_actions_log.permission_used is
  'The admin permission that authorised the action, if applicable.';
