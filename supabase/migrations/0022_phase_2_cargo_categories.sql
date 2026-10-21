-- ============================================================================
-- SafeShift — Phase 2 / Migration 0022
-- Hierarchical cargo catalogue categories.
-- ============================================================================

create table public.cargo_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  icon_url text,
  parent_category_id uuid references public.cargo_categories (id) on delete set null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cargo_categories_no_self_parent check (parent_category_id is null or parent_category_id <> id)
);

create trigger trg_cargo_categories_updated_at before update on public.cargo_categories
  for each row execute function public.set_updated_at();

