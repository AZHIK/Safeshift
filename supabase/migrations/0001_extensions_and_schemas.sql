-- ============================================================================
-- SafeShift — Phase 1 / Migration 0001
-- Extensions, schemas, and the shared updated_at trigger function.
--
-- This migration is the first file of a clean rebuild. It intentionally does
-- not depend on any prior schema.
-- ============================================================================

set search_path = public, extensions;

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
-- pgcrypto  : password hashing helpers used by local seed data + gen_random_uuid
-- postgis   : geography/geometry types for zones, addresses and driver location
-- pg_cron   : scheduled maintenance (partition rolling, retention jobs)
-- ----------------------------------------------------------------------------
create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;
create extension if not exists pg_cron;

-- ----------------------------------------------------------------------------
-- Private schema
-- ----------------------------------------------------------------------------
-- `private` holds append-only audit data and server-only helpers. It is not
-- exposed through PostgREST and is not accessible to anon/authenticated.
-- ----------------------------------------------------------------------------
create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

comment on schema private is
  'Server-only schema for audit data and internal helpers. Never exposed through the Data API.';

-- ----------------------------------------------------------------------------
-- Shared trigger function: set updated_at on every UPDATE
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Generic BEFORE UPDATE trigger function that stamps updated_at with now().';

revoke all on function public.set_updated_at() from public;
revoke all on function public.set_updated_at() from anon;
revoke all on function public.set_updated_at() from authenticated;
