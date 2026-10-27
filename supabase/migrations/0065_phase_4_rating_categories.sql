-- ============================================================================
-- SafeShift — Phase 4 / Migration 0065
-- Rating categories: what each side of the marketplace rates.
-- ============================================================================

create table public.rating_categories (
  id              uuid primary key default gen_random_uuid(),
  code            text not null,
  name            text not null,
  description     text,
  applies_to_role public.user_role not null,
  display_order   integer not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint rating_categories_code_key unique (code),
  constraint rating_categories_code_format_check
    check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint rating_categories_name_check check (length(btrim(name)) > 0),
  constraint rating_categories_role_check check (applies_to_role in ('customer', 'driver')),
  constraint rating_categories_order_check check (display_order >= 0)
);

comment on table public.rating_categories is
  'Catalogue of rating dimensions. applies_to_role identifies who gives the rating (customer rates driver, driver rates customer).';

comment on column public.rating_categories.applies_to_role is
  'The rater role, not the rated role. A customer-facing overall category is used by customers rating drivers.';
