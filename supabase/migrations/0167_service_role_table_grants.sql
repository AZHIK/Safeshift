-- Server-side (service_role) access to the public schema.
--
-- The migrations never grant table privileges to service_role. Locally the
-- Supabase CLI's default privileges grant them implicitly, but hosted projects
-- created without those defaults left 307 of 342 public tables closed to
-- service_role, so every edge function using the service client failed with
-- "permission denied for table …" (payments, payouts, refunds, jobs, payment
-- webhooks, notifications, data export…).
--
-- service_role is the server-only role: it bypasses RLS and is never handed to
-- clients. anon and authenticated keep their explicit, narrower grants.

grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;

-- Tables created later (including the monthly partitions made by maintenance
-- jobs running as the migration owner) get the same access.
alter default privileges in schema public grant all privileges on tables to service_role;
alter default privileges in schema public grant all privileges on sequences to service_role;
