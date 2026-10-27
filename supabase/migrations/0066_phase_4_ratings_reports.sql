-- ============================================================================
-- SafeShift — Phase 4 / Migration 0066
-- Per-trip ratings and rating moderation reports.
-- ============================================================================

create table public.ratings (
  id                 uuid primary key default gen_random_uuid(),
  job_id             uuid not null references public.jobs (id) on delete cascade,
  rater_profile_id   uuid not null references public.profiles (id) on delete cascade,
  rated_profile_id   uuid not null references public.profiles (id) on delete cascade,
  rated_role         public.user_role not null,
  rating_category_id uuid not null references public.rating_categories (id) on delete restrict,
  score              smallint not null,
  comment            text,
  is_anonymous       boolean not null default false,
  created_at         timestamptz not null default now(),

  constraint ratings_score_check check (score between 1 and 5),
  constraint ratings_self_check check (rater_profile_id <> rated_profile_id),
  constraint ratings_rated_role_check check (rated_role in ('customer', 'driver')),
  constraint ratings_job_rater_category_key unique (job_id, rater_profile_id, rating_category_id)
);

comment on table public.ratings is
  'One rating row per job/rater/category. The unique key prevents duplicate category submissions for the same job.';

comment on column public.ratings.is_anonymous is
  'Hides the rater identity from counterparty-facing displays; staff with manage_ratings can still investigate abuse.';

create table public.rating_reports (
  id           uuid primary key default gen_random_uuid(),
  rating_id    uuid not null references public.ratings (id) on delete cascade,
  reported_by  uuid not null references public.profiles (id) on delete restrict,
  reason       text not null,
  status       text not null default 'pending',
  reviewed_by  uuid references public.profiles (id) on delete set null,
  reviewed_at  timestamptz,
  review_notes text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint rating_reports_reason_check check (length(btrim(reason)) > 0),
  constraint rating_reports_status_check check (
    status in ('pending', 'reviewed_no_action', 'reviewed_removed', 'escalated')
  ),
  constraint rating_reports_rating_reporter_key unique (rating_id, reported_by)
);

comment on table public.rating_reports is
  'Abuse/suspicion reports against a rating. Support reviews and either keeps, removes or escalates the rating.';
