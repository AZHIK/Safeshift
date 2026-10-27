-- ============================================================================
-- SafeShift — Phase 4 / Migration 0053
-- Draft pricing-version visibility fix (Decision G).
--
-- Phase 3 exposed every pricing_plan_versions row to every authenticated user.
-- Published versions must remain globally readable so quotes are explainable.
-- Draft versions are internal working data and are now visible only to holders
-- of manage_pricing. pricing_plan_versions_manage already gives those users
-- full manage access; this migration narrows the general SELECT policy.
-- ============================================================================

drop policy if exists pricing_plan_versions_select_authenticated
  on public.pricing_plan_versions;

drop policy if exists pricing_plan_versions_select_published
  on public.pricing_plan_versions;
drop policy if exists pricing_plan_versions_select_drafts
  on public.pricing_plan_versions;

create policy pricing_plan_versions_select_published
  on public.pricing_plan_versions
  for select
  to authenticated
  using (published_at is not null);

create policy pricing_plan_versions_select_drafts
  on public.pricing_plan_versions
  for select
  to authenticated
  using (
    published_at is null
    and (select public.has_permission('manage_pricing'))
  );

comment on policy pricing_plan_versions_select_published on public.pricing_plan_versions is
  'Published versions are visible to every authenticated user so historical quotes can be explained.';

comment on policy pricing_plan_versions_select_drafts on public.pricing_plan_versions is
  'Draft versions are internal pricing work and are visible only to manage_pricing holders.';
