-- ============================================================================
-- 0098 — Phase 6: notification preferences
-- ============================================================================

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  channel text not null,
  is_enabled boolean not null default true,
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text,
  updated_at timestamptz not null default now(),
  constraint notification_preferences_category_check
    check (category in ('job_updates', 'payment', 'promotions', 'safety_alerts', 'chat', 'system')),
  constraint notification_preferences_channel_check
    check (channel in ('push', 'sms', 'email')),
  constraint notification_preferences_quiet_hours_pair_check
    check ((quiet_hours_start is null) = (quiet_hours_end is null)),
  constraint notification_preferences_scope_key unique (profile_id, category, channel)
);

comment on table public.notification_preferences is
  'Per-profile notification opt-in and quiet-hour settings by category and channel.';

create trigger trg_notification_preferences_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();
