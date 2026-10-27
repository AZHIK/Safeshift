-- ============================================================================
-- SafeShift — Phase 4 / Migration 0052
-- Operational enums.
--
-- Phase 1 deliberately deferred job/payment/evidence enums. Phase 4 introduces
-- them now. All other status-like fields remain TEXT + CHECK so operations can
-- add states without an enum migration.
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'job_status') then
    create type public.job_status as enum (
      'requested',
      'quoted',
      'matched',
      'accepted',
      'heading_to_pickup',
      'arrived',
      'loading',
      'in_transit',
      'delivered',
      'completed',
      'cancelled',
      'disputed'
    );
  end if;
end $$;

comment on type public.job_status is
  'Lifecycle of a job. Transitions are enforced by public.job_advance_status(); cancelled and completed are terminal for normal transitions.';

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'payment_status') then
    create type public.payment_status as enum (
      'pending',
      'paid',
      'refunded',
      'failed',
      'partially_refunded'
    );
  end if;
end $$;

comment on type public.payment_status is
  'Payment lifecycle for a job. Payment processor integration is Phase 5; Phase 4 records the state.';

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'payment_method') then
    create type public.payment_method as enum (
      'mpesa',
      'tigopesa',
      'airtelmoney',
      'halopesa',
      'card',
      'cash',
      'wallet'
    );
  end if;
end $$;

comment on type public.payment_method is
  'Supported customer payment methods for Tanzania launch. Phase 5 owns processor routing and settlement.';

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'evidence_type') then
    create type public.evidence_type as enum (
      'pickup_photo',
      'delivery_photo',
      'signature',
      'otp',
      'document',
      'item_photo',
      'cargo_manifest'
    );
  end if;
end $$;

comment on type public.evidence_type is
  'Kinds of proof attached to a job or job stop. Files live in object storage; the database stores paths and metadata only.';

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'trip_alert_type') then
    create type public.trip_alert_type as enum (
      'route_deviation',
      'prolonged_stop',
      'sos',
      'unusual_activity'
    );
  end if;
end $$;

comment on type public.trip_alert_type is
  'Safety/tracking alert categories emitted by the Phase 5/6 telemetry pipeline. Defined now so alert producers share one vocabulary.';
