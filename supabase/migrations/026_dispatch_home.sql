-- Dispatch home: job cost estimates, manager-visible profiles, last GPS pings.

alter table public.org_jobs
  add column if not exists estimated_miles numeric,
  add column if not exists estimated_cost numeric;

alter table public.profiles
  add column if not exists phone text not null default '';

comment on column public.org_jobs.estimated_miles is
  'Optional dispatcher estimate (OSRM or manual) in miles.';
comment on column public.org_jobs.estimated_cost is
  'Optional dispatcher estimated job cost in USD.';

drop policy if exists "Managers read org member profiles" on public.profiles;
create policy "Managers read org member profiles"
  on public.profiles for select
  to authenticated
  using (
    exists (
      select 1
      from public.org_members me
      join public.org_members them
        on them.org_id = me.org_id
      where me.user_id = auth.uid()
        and me.role in ('owner', 'admin')
        and them.user_id = profiles.user_id
    )
  );

create or replace function public.org_driver_last_locations(p_org_id uuid)
returns table (
  user_id uuid,
  lat double precision,
  lng double precision,
  seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;

  return query
  select distinct on (t.user_id)
    t.user_id,
    coalesce(t.end_lat, t.start_lat),
    coalesce(t.end_lng, t.start_lng),
    t.date::timestamptz
  from public.trips t
  join public.org_members m
    on m.user_id = t.user_id
   and m.org_id = p_org_id
  where coalesce(t.end_lat, t.start_lat) is not null
    and coalesce(t.end_lng, t.start_lng) is not null
  order by t.user_id, t.date desc, t.id desc;
end;
$$;

revoke all on function public.org_driver_last_locations(uuid) from public, anon;
grant execute on function public.org_driver_last_locations(uuid) to authenticated;
