-- Company job style (service = one site, delivery = pickup + dropoff)
-- and per-member pay (hourly / reimbursement / contractor).

alter table public.orgs
  add column if not exists job_style text not null default 'service',
  add column if not exists company_kind text not null default 'other',
  add column if not exists default_pay_type text not null default 'hourly';

alter table public.orgs drop constraint if exists orgs_job_style_check;
alter table public.orgs
  add constraint orgs_job_style_check
  check (job_style in ('service', 'delivery'));

alter table public.orgs drop constraint if exists orgs_company_kind_check;
alter table public.orgs
  add constraint orgs_company_kind_check
  check (company_kind in ('hvac', 'plumbing', 'landscaping', 'delivery', 'other'));

alter table public.orgs drop constraint if exists orgs_default_pay_type_check;
alter table public.orgs
  add constraint orgs_default_pay_type_check
  check (default_pay_type in ('hourly', 'reimbursement', 'contractor'));

alter table public.org_members
  add column if not exists pay_type text not null default 'hourly',
  add column if not exists hourly_rate numeric(8, 2);

alter table public.org_members drop constraint if exists org_members_pay_type_check;
alter table public.org_members
  add constraint org_members_pay_type_check
  check (pay_type in ('hourly', 'reimbursement', 'contractor'));

alter table public.org_members drop constraint if exists org_members_hourly_rate_check;
alter table public.org_members
  add constraint org_members_hourly_rate_check
  check (hourly_rate is null or hourly_rate >= 0);

drop function if exists public.create_org(text);

create or replace function public.create_org(
  org_name text,
  p_job_style text default 'service',
  p_company_kind text default 'other',
  p_default_pay_type text default 'hourly'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  oid uuid;
  style text := lower(trim(p_job_style));
  kind text := lower(trim(p_company_kind));
  pay text := lower(trim(p_default_pay_type));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if exists (select 1 from public.org_members where user_id = uid) then
    raise exception 'Already in a team';
  end if;
  if style not in ('service', 'delivery') then
    style := 'service';
  end if;
  if kind not in ('hvac', 'plumbing', 'landscaping', 'delivery', 'other') then
    kind := 'other';
  end if;
  if pay not in ('hourly', 'reimbursement', 'contractor') then
    pay := 'hourly';
  end if;

  insert into public.orgs (name, created_by, job_style, company_kind, default_pay_type)
  values (trim(org_name), uid, style, kind, pay)
  returning id into oid;

  insert into public.org_members (org_id, user_id, role, pay_type)
  values (oid, uid, 'owner', pay);

  return oid;
end;
$$;

create or replace function public.accept_org_invite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  em text;
  rec public.org_invites%rowtype;
  v_pay text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select lower(coalesce(auth.jwt() ->> 'email', '')) into em;

  select * into rec
  from public.org_invites
  where token = p_token
    and accepted_at is null
    and expires_at > now();

  if rec.id is null then
    raise exception 'Invite not found or expired';
  end if;
  if em = '' or lower(rec.email) <> em then
    raise exception 'Invite email does not match this account';
  end if;
  if exists (select 1 from public.org_members where user_id = uid) then
    raise exception 'Already in a team';
  end if;

  select default_pay_type into v_pay from public.orgs where id = rec.org_id;
  v_pay := coalesce(v_pay, 'hourly');

  insert into public.org_members (org_id, user_id, role, pay_type)
  values (rec.org_id, uid, rec.role, v_pay);

  update public.org_invites
  set accepted_at = now()
  where id = rec.id;

  return rec.org_id;
end;
$$;

create or replace function public.update_org_member_pay(
  p_org_id uuid,
  p_user_id uuid,
  p_pay_type text,
  p_hourly_rate numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  pay text := lower(trim(p_pay_type));
  rate numeric := p_hourly_rate;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if not exists (
    select 1 from public.org_members
    where org_id = p_org_id and user_id = p_user_id
  ) then
    raise exception 'Not on this team';
  end if;
  if pay not in ('hourly', 'reimbursement', 'contractor') then
    raise exception 'Invalid pay type';
  end if;
  if pay <> 'hourly' then
    rate := null;
  end if;

  update public.org_members
  set pay_type = pay, hourly_rate = rate
  where org_id = p_org_id and user_id = p_user_id;
end;
$$;

drop function if exists public.org_roster(uuid);

create or replace function public.org_roster(p_org_id uuid)
returns table (
  user_id uuid,
  email text,
  nickname text,
  role text,
  last_trip_date date,
  trips_this_month int,
  unclassified_this_month int,
  business_miles_this_month numeric,
  pay_type text,
  hourly_rate numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  month_start date := date_trunc('month', now())::date;
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
        and t.date >= month_start
    ) as trips_this_month,
    (
      select count(*)::int
      from public.trips t
      where t.user_id = m.user_id
        and t.date >= month_start
        and t.is_business is null
    ) as unclassified_this_month,
    (
      select coalesce(sum(t.miles), 0)
      from public.trips t
      where t.user_id = m.user_id
        and t.date >= month_start
        and t.is_business is true
    ) as business_miles_this_month,
    m.pay_type,
    m.hourly_rate
  from public.org_members m
  join auth.users u on u.id = m.user_id
  left join public.profiles p on p.user_id = m.user_id
  where m.org_id = p_org_id
  order by m.role, coalesce(p.nickname, u.email);
end;
$$;

drop function if exists public.org_roster_for_period(uuid, date, date);

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
  business_miles_this_period numeric,
  pay_type text,
  hourly_rate numeric
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
    ) as business_miles_this_period,
    m.pay_type,
    m.hourly_rate
  from public.org_members m
  join auth.users u on u.id = m.user_id
  left join public.profiles p on p.user_id = m.user_id
  where m.org_id = p_org_id
  order by m.role, coalesce(p.nickname, u.email);
end;
$$;

create or replace function public.update_org_style(
  p_org_id uuid,
  p_job_style text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  style text := lower(trim(p_job_style));
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if style not in ('service', 'delivery') then
    raise exception 'Invalid job style';
  end if;
  update public.orgs set job_style = style where id = p_org_id;
end;
$$;

revoke all on function public.create_org(text, text, text, text) from public, anon;
revoke all on function public.update_org_member_pay(uuid, uuid, text, numeric) from public, anon;
grant execute on function public.create_org(text, text, text, text) to authenticated;
grant execute on function public.update_org_member_pay(uuid, uuid, text, numeric) to authenticated;
grant execute on function public.update_org_style(uuid, text) to authenticated;
grant execute on function public.accept_org_invite(uuid) to authenticated;
grant execute on function public.org_roster(uuid) to authenticated;
grant execute on function public.org_roster_for_period(uuid, date, date) to authenticated;
