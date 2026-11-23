-- Two-way ratings after a move.
--
-- The customer rates the driver and the driver rates the customer once the
-- move is delivered. Like Bolt/Uber:
--   * one overall score (1-5) per side per job, optional quick tags and a
--     comment; it can be changed for 24 hours, and given for up to 7 days;
--   * ratings are anonymous: the rated person sees their average and
--     anonymised feedback, never who gave which score;
--   * averages (last 100 ratings within 180 days) update immediately on
--     drivers.rating / customers.rating.
-- Writes go through public.job_submit_rating only.

-- ----------------------------------------------------------------------------
-- Schema
-- ----------------------------------------------------------------------------

alter table public.ratings
  add column if not exists tags text[] not null default '{}',
  add column if not exists updated_at timestamptz not null default now();

alter table public.ratings
  alter column is_anonymous set default true;

alter table public.ratings drop constraint if exists ratings_comment_length_check;
alter table public.ratings
  add constraint ratings_comment_length_check
  check (comment is null or length(comment) <= 500);

alter table public.ratings drop constraint if exists ratings_tags_count_check;
alter table public.ratings
  add constraint ratings_tags_count_check
  check (coalesce(array_length(tags, 1), 0) <= 8);

alter table public.drivers
  add column if not exists rating_count integer not null default 0;
alter table public.customers
  add column if not exists rating_count integer not null default 0;

-- Overall category for drivers rating customers (customers already have one).
insert into public.rating_categories (code, name, description, applies_to_role, display_order)
values ('customer_overall', 'Overall', 'Driver''s overall rating of the customer for a move.', 'driver', 0)
on conflict (code) do nothing;

create index if not exists ratings_rated_recent_idx
  on public.ratings (rated_profile_id, created_at desc);

-- ----------------------------------------------------------------------------
-- Allowed quick tags, by who is rating and whether the score is good (4-5)
-- or poor (1-3). Kept in SQL so the server rejects unknown tags.
-- ----------------------------------------------------------------------------

create or replace function private.rating_tags(p_rater_role public.user_role, p_positive boolean)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case
    when p_rater_role = 'customer' and p_positive then
      array['on_time', 'careful_handling', 'friendly', 'clean_vehicle', 'good_route']
    when p_rater_role = 'customer' then
      array['late', 'rough_handling', 'rude', 'vehicle_condition', 'poor_route', 'damaged_items']
    when p_positive then
      array['ready_on_time', 'clear_directions', 'helped_loading', 'polite', 'accurate_cargo']
    else
      array['kept_waiting', 'cargo_not_as_described', 'hard_to_reach', 'rude', 'unsafe_loading']
  end;
$$;

-- ----------------------------------------------------------------------------
-- Aggregates
-- ----------------------------------------------------------------------------

create or replace function private.refresh_rating_aggregate(p_profile_id uuid, p_role public.user_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_avg   numeric;
  v_count integer;
begin
  select round(avg(score)::numeric, 2), count(*)::integer
    into v_avg, v_count
  from (
    select r.score
      from public.ratings r
     where r.rated_profile_id = p_profile_id
       and r.rated_role = p_role
       and r.created_at >= now() - interval '180 days'
     order by r.created_at desc
     limit 100
  ) recent;

  if p_role = 'driver' then
    update public.drivers
       set rating = coalesce(v_avg, 0), rating_count = coalesce(v_count, 0)
     where id = p_profile_id;
  elsif p_role = 'customer' then
    -- Not every customer profile has a customers row yet; create it.
    insert into public.customers (id, rating, rating_count)
    values (p_profile_id, v_avg, coalesce(v_count, 0))
    on conflict (id) do update
      set rating = excluded.rating,
          rating_count = excluded.rating_count,
          updated_at = now();
  end if;
end;
$$;

create or replace function private.trg_ratings_refresh_aggregate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform private.refresh_rating_aggregate(old.rated_profile_id, old.rated_role);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform private.refresh_rating_aggregate(new.rated_profile_id, new.rated_role);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_ratings_refresh_aggregate on public.ratings;
create trigger trg_ratings_refresh_aggregate
  after insert or update of score, rated_profile_id, rated_role or delete on public.ratings
  for each row execute function private.trg_ratings_refresh_aggregate();

revoke all on function private.rating_tags(public.user_role, boolean) from public, anon, authenticated;
revoke all on function private.refresh_rating_aggregate(uuid, public.user_role) from public, anon, authenticated;
revoke all on function private.trg_ratings_refresh_aggregate() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Access: reads for the rater and staff; writes only through the RPC.
-- The rated person reads anonymised feedback via driver_ratings_list /
-- my_rating_summary, so they never see who rated them.
-- ----------------------------------------------------------------------------

drop policy if exists ratings_insert_counterparty on public.ratings;
revoke insert, update, delete on public.ratings from authenticated, anon;

drop policy if exists ratings_select_rater_rated_or_staff on public.ratings;
drop policy if exists ratings_select_rater_or_staff on public.ratings;
create policy ratings_select_rater_or_staff on public.ratings
  for select to authenticated
  using (
    rater_profile_id = (select auth.uid())
    or (select public.has_permission('view_all_ratings'))
  );

-- Anonymised list for the rated person (drivers' profile screen).
create or replace function public.driver_ratings_list(p_limit integer default 50)
returns table (
  rating_id uuid,
  score smallint,
  comment text,
  created_at timestamptz,
  rater_name text,
  job_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.score,
    r.comment,
    -- Day precision only, so a rating cannot be matched to a trip by time.
    date_trunc('day', r.created_at),
    case when r.is_anonymous then 'Anonymous' else coalesce(p.full_name, p.display_name) end,
    case when r.is_anonymous then null else r.job_id end
  from public.ratings r
  left join public.profiles p on p.id = r.rater_profile_id
  where r.rated_profile_id = auth.uid()
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

-- ----------------------------------------------------------------------------
-- RPCs
-- ----------------------------------------------------------------------------

-- What the caller may do for a job: their current rating (if any), whether
-- they can still rate or edit, and the tags they may choose from.
create or replace function public.job_rating_status(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_job   public.jobs%rowtype;
  v_role  public.user_role;
  v_mine  public.ratings%rowtype;
  v_done_at timestamptz;
  v_can_rate boolean;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;
  if v_actor = v_job.customer_id then
    v_role := 'customer';
  elsif v_actor = v_job.driver_id then
    v_role := 'driver';
  else
    raise exception 'only the customer or driver of this move can rate it'
      using errcode = '42501';
  end if;

  select * into v_mine from public.ratings
   where job_id = p_job_id and rater_profile_id = v_actor
   order by created_at limit 1;

  v_done_at := coalesce(v_job.completed_at, v_job.updated_at);
  v_can_rate := v_job.status in ('delivered', 'completed')
    and v_job.driver_id is not null
    and (
      (v_mine.id is null and v_done_at > now() - interval '7 days')
      or (v_mine.id is not null and v_mine.created_at > now() - interval '24 hours')
    );

  return jsonb_build_object(
    'rater_role', v_role,
    'can_rate', v_can_rate,
    'rated', v_mine.id is not null,
    'score', v_mine.score,
    'tags', coalesce(to_jsonb(v_mine.tags), '[]'::jsonb),
    'comment', v_mine.comment,
    'positive_tags', to_jsonb(private.rating_tags(v_role, true)),
    'negative_tags', to_jsonb(private.rating_tags(v_role, false))
  );
end;
$$;

create or replace function public.job_submit_rating(
  p_job_id uuid,
  p_score integer,
  p_tags text[] default '{}',
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor    uuid := auth.uid();
  v_job      public.jobs%rowtype;
  v_role     public.user_role;
  v_rated    uuid;
  v_category uuid;
  v_existing public.ratings%rowtype;
  v_tags     text[];
  v_allowed  text[];
  v_comment  text := nullif(btrim(coalesce(p_comment, '')), '');
  v_done_at  timestamptz;
begin
  if v_actor is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_score is null or p_score not between 1 and 5 then
    raise exception 'choose between 1 and 5 stars' using errcode = '22023';
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'job % not found', p_job_id using errcode = 'P0002';
  end if;

  if v_actor = v_job.customer_id then
    v_role := 'customer';
    v_rated := v_job.driver_id;
  elsif v_actor = v_job.driver_id then
    v_role := 'driver';
    v_rated := v_job.customer_id;
  else
    raise exception 'only the customer or driver of this move can rate it'
      using errcode = '42501';
  end if;

  if v_rated is null or v_job.status not in ('delivered', 'completed') then
    raise exception 'you can rate once the move has been delivered'
      using errcode = '22023';
  end if;

  select c.id into v_category
    from public.rating_categories c
   where c.code = case when v_role = 'customer' then 'overall' else 'customer_overall' end
     and c.is_active;
  if v_category is null then
    raise exception 'ratings are not available right now' using errcode = 'P0002';
  end if;

  -- Tags must match the score's tone; unknown ones are rejected.
  v_allowed := private.rating_tags(v_role, p_score >= 4);
  select coalesce(array_agg(distinct t), '{}') into v_tags
    from unnest(coalesce(p_tags, '{}')) t
   where btrim(t) <> '';
  if exists (select 1 from unnest(v_tags) t where t <> all (v_allowed)) then
    raise exception 'one of the selected tags does not fit this rating'
      using errcode = '22023';
  end if;
  if v_comment is not null and length(v_comment) > 500 then
    raise exception 'keep the comment under 500 characters' using errcode = '22023';
  end if;

  select * into v_existing from public.ratings
   where job_id = p_job_id and rater_profile_id = v_actor
   for update;

  if found then
    if v_existing.created_at <= now() - interval '24 hours' then
      raise exception 'ratings can only be changed within 24 hours'
        using errcode = '22023';
    end if;
    update public.ratings
       set score = p_score,
           tags = v_tags,
           comment = v_comment,
           rating_category_id = v_category,
           updated_at = now()
     where id = v_existing.id;
  else
    v_done_at := coalesce(v_job.completed_at, v_job.updated_at);
    if v_done_at <= now() - interval '7 days' then
      raise exception 'this move can no longer be rated' using errcode = '22023';
    end if;
    insert into public.ratings (
      job_id, rater_profile_id, rated_profile_id, rated_role,
      rating_category_id, score, comment, tags, is_anonymous
    ) values (
      p_job_id, v_actor, v_rated,
      case when v_role = 'customer' then 'driver'::public.user_role else 'customer'::public.user_role end,
      v_category, p_score, v_comment, v_tags, true
    );
  end if;

  return public.job_rating_status(p_job_id);
end;
$$;

-- The caller's own reputation: average, count and the tags others chose
-- most, without any rater identity.
create or replace function public.my_rating_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select r.score, r.tags
      from public.ratings r
     where r.rated_profile_id = auth.uid()
       and r.created_at >= now() - interval '180 days'
     order by r.created_at desc
     limit 100
  )
  select jsonb_build_object(
    'average', (select round(avg(score)::numeric, 2) from mine),
    'count', (select count(*) from mine),
    'top_tags', coalesce((
      select jsonb_agg(jsonb_build_object('tag', tag, 'count', n) order by n desc)
        from (
          select t as tag, count(*) as n
            from mine, unnest(mine.tags) t
           group by t
           order by count(*) desc
           limit 5
        ) top
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.job_rating_status(uuid) from public, anon;
revoke all on function public.job_submit_rating(uuid, integer, text[], text) from public, anon;
revoke all on function public.my_rating_summary() from public, anon;
revoke all on function public.driver_ratings_list(integer) from public, anon;
grant execute on function public.job_rating_status(uuid) to authenticated, service_role;
grant execute on function public.job_submit_rating(uuid, integer, text[], text) to authenticated, service_role;
grant execute on function public.my_rating_summary() to authenticated, service_role;
grant execute on function public.driver_ratings_list(integer) to authenticated, service_role;

-- Bring stored averages in line with the new rule.
do $$
declare r record;
begin
  for r in select distinct rated_profile_id, rated_role from public.ratings loop
    perform private.refresh_rating_aggregate(r.rated_profile_id, r.rated_role);
  end loop;
end;
$$;
