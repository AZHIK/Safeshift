-- ============================================================================
-- SafeShift — Phase 3 / Migration 0040
-- Immutable, versioned pricing rulesets.
--
-- Lifecycle: draft (published_at IS NULL) -> published -> superseded.
-- A published version is never edited in place: new prices mean a new version.
-- Migration 0047 installs the trigger that enforces this, and migration 0050
-- provides publish_pricing_plan_version() for the atomic transition.
--
-- A quote will always store the version_id it used (Phase 4). There is no
-- mutable "current version" pointer anywhere in the schema.
-- ============================================================================

create table public.pricing_plan_versions (
  id                     uuid primary key default gen_random_uuid(),
  pricing_plan_id        uuid not null references public.pricing_plans (id) on delete restrict,
  version_number         integer not null,
  currency_code          char(3) not null references public.currencies (code) on update cascade on delete restrict,
  effective_from         timestamptz not null,
  effective_to           timestamptz,
  published_at           timestamptz,
  published_by           uuid references public.profiles (id) on delete set null,
  superseded_by_version_id uuid references public.pricing_plan_versions (id) on delete set null,
  regulated_tariff_id    uuid references public.regulated_tariffs (id) on delete restrict,
  notes                  text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint pricing_plan_versions_number_check check (version_number > 0),
  constraint pricing_plan_versions_window_check
    check (effective_to is null or effective_to > effective_from),
  constraint pricing_plan_versions_self_supersede_check
    check (superseded_by_version_id is null or superseded_by_version_id <> id),
  constraint pricing_plan_versions_plan_number_key
    unique (pricing_plan_id, version_number)
);

comment on table public.pricing_plan_versions is
  'Immutable published pricing ruleset. Draft rows are editable; once published_at is set only the supersede fields may change, via publish_pricing_plan_version().';

comment on column public.pricing_plan_versions.superseded_by_version_id is
  'Set once by publish_pricing_plan_version() when a newer version takes over. Historical rows are retained forever.';

comment on column public.pricing_plan_versions.regulated_tariff_id is
  'When set, the quoted total for this version is capped at public.regulated_max_fare() for the applicable band.';

create trigger trg_pricing_plan_versions_updated_at
  before update on public.pricing_plan_versions
  for each row execute function public.set_updated_at();

-- The target table now exists; install the Phase 1 integration FK.
select private.ensure_zone_pricing_override_fk();

comment on column public.zone_pricing_overrides.pricing_plan_id is
  'Phase 3 pricing plan version this override applies to. The FK to pricing_plan_versions is installed in migration 0040.';
