-- Team dashboard: period roster, trip list, leave / remove member.
-- Managers still read-only on another driver's rows.

-- SQL editor treats `SELECT * INTO rec` as CREATE TABLE rec.
-- Drop it if an earlier paste created that leftover.
drop table if exists public.rec;

create or replace function public.leave_org()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  v_org_id uuid;
  v_role text;
  others int;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select org_id, role
    into v_org_id, v_role
  from public.org_members
  where user_id = uid;

  if v_org_id is null then
    raise exception 'Not in a team';
  end if;

  if v_role = 'owner' then
    select count(*) into others
    from public.org_members
    where org_id = v_org_id
      and user_id <> uid;
    if others > 0 then
      raise exception 'Owner must remove other members before leaving';
    end if;
    delete from public.orgs where id = v_org_id;
    return;
  end if;

  delete from public.org_members
  where org_id = v_org_id
    and user_id = uid;
end;
$$;

create or replace function public.remove_org_member(p_org_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  target_role text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if p_user_id = uid then
    raise exception 'Leave the team instead of removing yourself';
  end if;

  select role into target_role
  from public.org_members
  where org_id = p_org_id
    and user_id = p_user_id;

  if target_role is null then
    raise exception 'Member not found';
  end if;
  if target_role = 'owner' then
    raise exception 'Cannot remove the team owner';
  end if;

  delete from public.org_members
  where org_id = p_org_id
    and user_id = p_user_id;
end;
$$;

create or replace function public.org_roster_for_period(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  user_id uuid,
  email text,
  nickname text,
  role text,
  last_trip_date date,
  trips_this_period int,
  unclassified_this_period int,
  business_miles_this_period numeric
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
  select
    m.user_id,
    u.email::text,
    coalesce(p.nickname, ''),
    m.role,
    (
      select max(t.date)
      from public.trips t
      where t.user_id = m.user_id
    ) as last_trip_date,
    (
      select count(*)::int
      from public.trips t
      where t.user_id = m.user_id
        and t.date >= p_start
        and t.date <= p_end
    ) as trips_this_period,
    (
      select count(*)::int
      from public.trips t
      where t.user_id = m.user_id
        and t.date >= p_start
        and t.date <= p_end
        and t.is_business is null
    ) as unclassified_this_period,
    (
      select coalesce(sum(t.miles), 0)
      from public.trips t
      where t.user_id = m.user_id
        and t.date >= p_start
        and t.date <= p_end
        and t.is_business is true
    ) as business_miles_this_period
  from public.org_members m
  join auth.users u on u.id = m.user_id
  left join public.profiles p on p.user_id = m.user_id
  where m.org_id = p_org_id
  order by m.role, coalesce(p.nickname, u.email);
end;
$$;

create or replace function public.org_period_trips(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  trip_id bigint,
  user_id uuid,
  email text,
  nickname text,
  trip_date date,
  miles numeric,
  is_business boolean,
  notes text,
  source text,
  tips numeric
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
  select
    t.id,
    t.user_id,
    u.email::text,
    coalesce(p.nickname, ''),
    t.date,
    t.miles,
    t.is_business,
    t.notes,
    t.source,
    t.tips
  from public.trips t
  join public.org_members m
    on m.user_id = t.user_id
   and m.org_id = p_org_id
  join auth.users u on u.id = t.user_id
  left join public.profiles p on p.user_id = t.user_id
  where t.date >= p_start
    and t.date <= p_end
  order by t.date desc, t.id desc
  limit 2000;
end;
$$;

revoke all on function public.leave_org() from public, anon;
revoke all on function public.remove_org_member(uuid, uuid) from public, anon;
revoke all on function public.org_roster_for_period(uuid, date, date) from public, anon;
revoke all on function public.org_period_trips(uuid, date, date) from public, anon;
grant execute on function public.leave_org() to authenticated;
grant execute on function public.remove_org_member(uuid, uuid) to authenticated;
grant execute on function public.org_roster_for_period(uuid, date, date) to authenticated;
grant execute on function public.org_period_trips(uuid, date, date) to authenticated;
