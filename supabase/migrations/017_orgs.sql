-- Teams / B2B: orgs, members, invites.
-- Admins can READ org-mates' trips, expenses, profiles, period_earnings.
-- They cannot update or delete another driver's rows.

create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.org_members (
  org_id uuid not null references public.orgs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'driver')),
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create index if not exists idx_org_members_user on public.org_members (user_id);

create table if not exists public.org_invites (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs (id) on delete cascade,
  email text not null,
  role text not null default 'driver' check (role in ('admin', 'driver')),
  token uuid not null default gen_random_uuid() unique,
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz
);

create index if not exists idx_org_invites_org on public.org_invites (org_id);
create index if not exists idx_org_invites_email on public.org_invites (lower(email));
create unique index if not exists idx_org_invites_pending_email
  on public.org_invites (org_id, lower(email))
  where accepted_at is null;

create index if not exists idx_trips_unclassified
  on public.trips (user_id, date desc)
  where is_business is null;

alter table public.orgs enable row level security;
alter table public.org_members enable row level security;
alter table public.org_invites enable row level security;

-- Avoid RLS recursion: these run as definer and only filter by auth.uid().
create or replace function public.user_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select org_id
  from public.org_members
  where user_id = (select auth.uid());
$$;

create or replace function public.is_org_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.org_members
    where user_id = (select auth.uid())
      and role in ('owner', 'admin')
  );
$$;

create or replace function public.is_org_manager_of(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.org_members me
    join public.org_members them on them.org_id = me.org_id
    where me.user_id = (select auth.uid())
      and me.role in ('owner', 'admin')
      and them.user_id = target
  );
$$;

create or replace function public.is_org_manager_of_org(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.org_members
    where org_id = p_org_id
      and user_id = (select auth.uid())
      and role in ('owner', 'admin')
  );
$$;

revoke all on function public.user_org_ids() from public, anon;
revoke all on function public.is_org_manager() from public, anon;
revoke all on function public.is_org_manager_of(uuid) from public, anon;
revoke all on function public.is_org_manager_of_org(uuid) from public, anon;
grant execute on function public.user_org_ids() to authenticated;
grant execute on function public.is_org_manager() to authenticated;
grant execute on function public.is_org_manager_of(uuid) to authenticated;
grant execute on function public.is_org_manager_of_org(uuid) to authenticated;

drop policy if exists "Members read own orgs" on public.orgs;
create policy "Members read own orgs"
  on public.orgs for select
  to authenticated
  using (id in (select public.user_org_ids()));

drop policy if exists "Managers update own orgs" on public.orgs;
create policy "Managers update own orgs"
  on public.orgs for update
  to authenticated
  using (public.is_org_manager_of_org(id))
  with check (public.is_org_manager_of_org(id));

drop policy if exists "Members read org roster" on public.org_members;
create policy "Members read org roster"
  on public.org_members for select
  to authenticated
  using (org_id in (select public.user_org_ids()));

drop policy if exists "Managers read org invites" on public.org_invites;
create policy "Managers read org invites"
  on public.org_invites for select
  to authenticated
  using (public.is_org_manager_of_org(org_id));

drop policy if exists "Managers insert org invites" on public.org_invites;
create policy "Managers insert org invites"
  on public.org_invites for insert
  to authenticated
  with check (public.is_org_manager_of_org(org_id));

drop policy if exists "Managers delete org invites" on public.org_invites;
create policy "Managers delete org invites"
  on public.org_invites for delete
  to authenticated
  using (public.is_org_manager_of_org(org_id));

-- Extra SELECT for org managers (own-row policies already exist).
drop policy if exists "Org managers read member trips" on public.trips;
create policy "Org managers read member trips"
  on public.trips for select
  to authenticated
  using (public.is_org_manager_of(user_id));

drop policy if exists "Org managers read member expenses" on public.expenses;
create policy "Org managers read member expenses"
  on public.expenses for select
  to authenticated
  using (public.is_org_manager_of(user_id));

drop policy if exists "Org managers read member profiles" on public.profiles;
create policy "Org managers read member profiles"
  on public.profiles for select
  to authenticated
  using (public.is_org_manager_of(user_id));

drop policy if exists "Org managers read member earnings" on public.period_earnings;
create policy "Org managers read member earnings"
  on public.period_earnings for select
  to authenticated
  using (public.is_org_manager_of(user_id));

-- Mutations for orgs/members go through SECURITY DEFINER RPCs.
grant select, update on public.orgs to authenticated;
grant select on public.org_members to authenticated;
grant select, insert, delete on public.org_invites to authenticated;
grant usage, select on sequence public.org_invites_id_seq to authenticated;

create or replace function public.create_org(org_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  oid uuid;
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

  insert into public.orgs (name, created_by)
  values (trim(org_name), uid)
  returning id into oid;

  insert into public.org_members (org_id, user_id, role)
  values (oid, uid, 'owner');

  return oid;
end;
$$;

create or replace function public.invite_to_org(p_org_id uuid, p_email text, p_role text default 'driver')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  tok uuid;
  r text := lower(trim(p_role));
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
  if r not in ('admin', 'driver') then
    raise exception 'Role must be admin or driver';
  end if;
  if position('@' in lower(trim(p_email))) = 0 then
    raise exception 'Enter a valid email';
  end if;

  insert into public.org_invites (org_id, email, role, invited_by)
  values (p_org_id, lower(trim(p_email)), r, uid)
  returning token into tok;

  return tok;
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

  insert into public.org_members (org_id, user_id, role)
  values (rec.org_id, uid, rec.role);

  update public.org_invites
  set accepted_at = now()
  where id = rec.id;

  return rec.org_id;
end;
$$;

create or replace function public.org_roster(p_org_id uuid)
returns table (
  user_id uuid,
  email text,
  nickname text,
  role text,
  last_trip_date date,
  trips_this_month int,
  unclassified_this_month int,
  business_miles_this_month numeric
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
    ) as business_miles_this_month
  from public.org_members m
  join auth.users u on u.id = m.user_id
  left join public.profiles p on p.user_id = m.user_id
  where m.org_id = p_org_id
  order by m.role, coalesce(p.nickname, u.email);
end;
$$;

create or replace function public.org_unclassified_trips(p_org_id uuid)
returns table (
  trip_id bigint,
  user_id uuid,
  email text,
  nickname text,
  trip_date date,
  miles numeric,
  notes text,
  source text
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
    t.id,
    t.user_id,
    u.email::text,
    coalesce(p.nickname, ''),
    t.date,
    t.miles,
    t.notes,
    t.source
  from public.trips t
  join public.org_members m
    on m.user_id = t.user_id
   and m.org_id = p_org_id
  join auth.users u on u.id = t.user_id
  left join public.profiles p on p.user_id = t.user_id
  where t.is_business is null
    and t.date >= month_start
  order by t.date desc, t.id desc
  limit 200;
end;
$$;

revoke all on function public.create_org(text) from public, anon;
revoke all on function public.invite_to_org(uuid, text, text) from public, anon;
revoke all on function public.accept_org_invite(uuid) from public, anon;
revoke all on function public.org_roster(uuid) from public, anon;
revoke all on function public.org_unclassified_trips(uuid) from public, anon;
grant execute on function public.create_org(text) to authenticated;
grant execute on function public.invite_to_org(uuid, text, text) to authenticated;
grant execute on function public.accept_org_invite(uuid) to authenticated;
grant execute on function public.org_roster(uuid) to authenticated;
grant execute on function public.org_unclassified_trips(uuid) to authenticated;

comment on table public.orgs is 'B2B team. Phone still logs; dashboard is roster + unclassified.';
comment on table public.org_members is 'One team per user in v1. owner/admin can read member trips.';
comment on table public.org_invites is 'Pending email invites. Driver accepts from the web app after sign-in.';

-- Account wipe: drop memberships first.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.org_invites where invited_by = uid;
  delete from public.org_members where user_id = uid;

  perform public.delete_own_expenses();
  perform public.delete_own_period_earnings();

  delete from public.places where user_id = uid;
  delete from public.vehicles where user_id = uid;
  delete from public.trips where user_id = uid;
  delete from public.settings where user_id = uid;
  delete from public.entitlements where user_id = uid;
  delete from public.legal_acceptance_events where user_id = uid;
  delete from public.profiles where user_id = uid;
  delete from public.live_activity_tokens where user_id = uid;

  delete from auth.users where id = uid;
end;
$$;
