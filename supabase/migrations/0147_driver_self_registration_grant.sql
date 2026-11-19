-- Driver onboarding inserts the caller's own driver row before creating
-- documents and verification requests. RLS drivers_insert_self already limits
-- this to auth.uid() with pending, unverified trust fields.
grant insert on public.drivers to authenticated;
