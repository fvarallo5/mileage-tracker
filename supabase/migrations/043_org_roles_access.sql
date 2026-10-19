-- Owner > Admin > Dispatcher > Driver.
-- Owner and Admin invite and set dispatcher desk pages at invite time.
-- Paste in the SQL editor, then hard-refresh the dashboard.

create or replace function public.org_role_rank(p_role text)
returns integer
language sql
immutable
as $$
  select case lower(coalesce(p_role, ''))
    when 'owner' then 4
    when 'admin' then 3
    when 'dispatcher' then 2
    when 'driver' then 1
    else 0
  end;
$$;

create or replace function public.org_normalize_access(p_role text, p_access jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  r text := lower(trim(coalesce(p_role, '')));
  src jsonb := coalesce(p_access, '{}'::jsonb);
  page text;
  allowed text[] := array['today', 'plan', 'review', 'books'];
  pages jsonb := '{}'::jsonb;
begin
  if r in ('owner', 'admin') then
    return jsonb_build_object(
      'today', true, 'plan', true, 'review', true, 'books', true, 'people', true, 'settings', true
    );
  end if;
  if r <> 'dispatcher' then
    return jsonb_build_object(
      'today', false, 'plan', false, 'review', false, 'books', false, 'people', false, 'settings', false
    );
  end if;
  foreach page in array allowed loop
    pages := pages || jsonb_build_object(
      page,
      coalesce((src ->> page)::boolean, page <> 'books')
    );
  end loop;
  pages := pages || jsonb_build_object('people', false, 'settings', false);
  return pages;
end;
$$;

do $$
declare
  c name;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'org_members'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%role%'
  loop
    execute format('alter table public.org_members drop constraint %I', c);
  end loop;
  for c in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'org_invites'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%role%'
  loop
    execute format('alter table public.org_invites drop constraint %I', c);
  end loop;
end $$;

alter table public.org_members
  add constraint org_members_role_check
  check (role in ('owner', 'admin', 'dispatcher', 'driver'));

alter table public.org_invites
  add constraint org_invites_role_check
  check (role in ('admin', 'dispatcher', 'driver'));

alter table public.org_members
  add column if not exists access jsonb not null default '{}'::jsonb;

alter table public.org_invites
  add column if not exists access jsonb not null default '{}'::jsonb;

update public.org_members
set access = public.org_normalize_access(role, access)
where access is distinct from public.org_normalize_access(role, access)
   or access = '{}'::jsonb;

update public.org_invites
set access = public.org_normalize_access(role, access)
where accepted_at is null
  and (
    access is distinct from public.org_normalize_access(role, access)
    or access = '{}'::jsonb
  );

create or replace function public.is_org_desk_of_org(p_org_id uuid)
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
      and role in ('owner', 'admin', 'dispatcher')
  );
$$;

create or replace function public.is_org_desk_of(target uuid)
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
      and me.role in ('owner', 'admin', 'dispatcher')
      and them.user_id = target
  );
$$;

create or replace function public.org_can(p_org_id uuid, p_page text)
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
      and (
        role in ('owner', 'admin')
        or (
          role = 'dispatcher'
          and coalesce((access ->> p_page)::boolean, false)
        )
      )
  );
$$;

create or replace function public.org_can_any(p_org_id uuid, p_pages text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from unnest(p_pages) as page
    where public.org_can(p_org_id, page)
  );
$$;

revoke all on function public.org_role_rank(text) from public, anon;
revoke all on function public.org_normalize_access(text, jsonb) from public, anon;
revoke all on function public.is_org_desk_of_org(uuid) from public, anon;
revoke all on function public.is_org_desk_of(uuid) from public, anon;
revoke all on function public.org_can(uuid, text) from public, anon;
revoke all on function public.org_can_any(uuid, text[]) from public, anon;
grant execute on function public.org_role_rank(text) to authenticated;
grant execute on function public.org_normalize_access(text, jsonb) to authenticated;
grant execute on function public.is_org_desk_of_org(uuid) to authenticated;
grant execute on function public.is_org_desk_of(uuid) to authenticated;
grant execute on function public.org_can(uuid, text) to authenticated;
grant execute on function public.org_can_any(uuid, text[]) to authenticated;

drop policy if exists "Managers and assignee read jobs" on public.org_jobs;
create policy "Managers and assignee read jobs"
  on public.org_jobs for select
  using (
    public.org_can_any(org_id, array['today', 'plan', 'review', 'books'])
    or assigned_user_id = auth.uid()
  );

drop policy if exists "Managers insert jobs" on public.org_jobs;
create policy "Managers insert jobs"
  on public.org_jobs for insert
  with check (public.org_can(org_id, 'today'));

drop policy if exists "Managers update jobs" on public.org_jobs;
create policy "Managers update jobs"
  on public.org_jobs for update
  using (public.org_can(org_id, 'today'))
  with check (public.org_can(org_id, 'today'));

drop policy if exists "Managers delete jobs" on public.org_jobs;
create policy "Managers delete jobs"
  on public.org_jobs for delete
  using (public.org_can(org_id, 'today'));

drop policy if exists "Managers read customers" on public.org_customers;
create policy "Managers read customers"
  on public.org_customers for select
  using ((select public.org_can_any(org_id, array['today', 'books'])));

drop policy if exists "Managers insert customers" on public.org_customers;
create policy "Managers insert customers"
  on public.org_customers for insert
  with check ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers update customers" on public.org_customers;
create policy "Managers update customers"
  on public.org_customers for update
  using ((select public.org_can(org_id, 'books')))
  with check ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers delete customers" on public.org_customers;
create policy "Managers delete customers"
  on public.org_customers for delete
  using ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers read driver hours" on public.org_driver_hours;
create policy "Managers read driver hours"
  on public.org_driver_hours for select
  to authenticated
  using ((select public.is_org_desk_of_org(org_id)));

drop policy if exists "Managers read org member profiles" on public.profiles;
create policy "Managers read org member profiles"
  on public.profiles for select
  to authenticated
  using (public.is_org_desk_of(user_id));

drop policy if exists "Org managers read member trips" on public.trips;
create policy "Org managers read member trips"
  on public.trips for select
  to authenticated
  using (public.is_org_desk_of(user_id));

drop policy if exists "Org managers read member expenses" on public.expenses;
create policy "Org managers read member expenses"
  on public.expenses for select
  to authenticated
  using (public.is_org_desk_of(user_id));

drop policy if exists "Org managers read member profiles" on public.profiles;
create policy "Org managers read member profiles"
  on public.profiles for select
  to authenticated
  using (public.is_org_desk_of(user_id));

drop policy if exists "Org managers read member earnings" on public.period_earnings;
create policy "Org managers read member earnings"
  on public.period_earnings for select
  to authenticated
  using (public.is_org_desk_of(user_id));

drop function if exists public.invite_to_org(uuid, text, text);

create or replace function public.invite_to_org(
  p_org_id uuid,
  p_email text,
  p_role text default 'driver',
  p_access jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  me_role text;
  tok uuid;
  r text := lower(trim(p_role));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select role into me_role
  from public.org_members
  where org_id = p_org_id and user_id = uid;

  if public.org_role_rank(me_role) < 3 then
    raise exception 'Only the owner or an admin can invite';
  end if;
  if r not in ('admin', 'dispatcher', 'driver') then
    raise exception 'Role must be admin, dispatcher, or driver';
  end if;
  if position('@' in lower(trim(p_email))) = 0 then
    raise exception 'Enter a valid email';
  end if;

  insert into public.org_invites (org_id, email, role, access, invited_by)
  values (p_org_id, lower(trim(p_email)), r, public.org_normalize_access(r, p_access), uid)
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

  insert into public.org_members (org_id, user_id, role, access)
  values (rec.org_id, uid, rec.role, public.org_normalize_access(rec.role, rec.access));

  update public.org_invites
  set accepted_at = now()
  where id = rec.id;

  return rec.org_id;
end;
$$;

create or replace function public.update_org_member_access(
  p_org_id uuid,
  p_user_id uuid,
  p_role text,
  p_access jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  me_role text;
  target_role text;
  r text := lower(trim(p_role));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select role into me_role
  from public.org_members
  where org_id = p_org_id and user_id = uid;

  select role into target_role
  from public.org_members
  where org_id = p_org_id and user_id = p_user_id;

  if public.org_role_rank(me_role) < 3 then
    raise exception 'Only the owner or an admin can edit access';
  end if;
  if target_role is null then
    raise exception 'Member not found';
  end if;
  if target_role = 'owner' then
    raise exception 'The owner role stays with the account that created the team';
  end if;
  if r not in ('admin', 'dispatcher', 'driver') then
    raise exception 'Role must be admin, dispatcher, or driver';
  end if;

  update public.org_members
  set role = r, access = public.org_normalize_access(r, p_access)
  where org_id = p_org_id and user_id = p_user_id;
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
  me_role text;
  target_role text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select role into me_role
  from public.org_members
  where org_id = p_org_id and user_id = uid;

  if public.org_role_rank(me_role) < 3 then
    raise exception 'Only the owner or an admin can remove people';
  end if;
  if p_user_id = uid then
    raise exception 'Leave the team instead of removing yourself';
  end if;

  select role into target_role
  from public.org_members
  where org_id = p_org_id and user_id = p_user_id;

  if target_role is null then
    raise exception 'Member not found';
  end if;
  if target_role = 'owner' then
    raise exception 'Cannot remove the team owner';
  end if;

  delete from public.org_members
  where org_id = p_org_id and user_id = p_user_id;
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
  if not public.is_org_desk_of_org(p_org_id) then
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
  order by public.org_role_rank(m.role) desc, coalesce(p.nickname, u.email);
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
  if not public.is_org_desk_of_org(p_org_id) then
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
  order by public.org_role_rank(m.role) desc, coalesce(p.nickname, u.email);
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
  if not public.is_org_desk_of_org(p_org_id) then
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

create or replace function public.org_period_expenses(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  expense_id bigint,
  user_id uuid,
  email text,
  nickname text,
  expense_date date,
  amount numeric,
  merchant text,
  category text,
  notes text,
  has_receipt boolean
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
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if not public.is_org_desk_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;

  return query
  select
    e.id,
    e.user_id,
    u.email::text,
    coalesce(p.nickname, ''),
    e.date,
    e.amount,
    e.merchant,
    e.category,
    e.notes,
    (e.receipt_path is not null and length(trim(e.receipt_path)) > 0)
  from public.expenses e
  join public.org_members m
    on m.user_id = e.user_id
   and m.org_id = p_org_id
  join auth.users u on u.id = e.user_id
  left join public.profiles p on p.user_id = e.user_id
  where e.date >= p_start
    and e.date <= p_end
  order by e.date desc, e.id desc
  limit 2000;
end;
$$;

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
  if not public.is_org_desk_of_org(p_org_id) then
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

create or replace function public.org_job_miles(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  job_id bigint,
  miles numeric
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
  if not public.is_org_desk_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;

  return query
  select t.job_id, sum(t.miles)
    from public.trips t
    join public.org_members m
      on m.user_id = t.user_id
     and m.org_id = p_org_id
   where t.job_id is not null
     and t.date >= p_start
     and t.date <= p_end
   group by t.job_id;
end;
$$;

drop policy if exists "Managers read books" on public.org_books_documents;
create policy "Managers read books"
  on public.org_books_documents for select
  using ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers insert books" on public.org_books_documents;
create policy "Managers insert books"
  on public.org_books_documents for insert
  with check ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers update books" on public.org_books_documents;
create policy "Managers update books"
  on public.org_books_documents for update
  using ((select public.org_can(org_id, 'books')))
  with check ((select public.org_can(org_id, 'books')));

drop policy if exists "Managers delete books" on public.org_books_documents;
create policy "Managers delete books"
  on public.org_books_documents for delete
  using ((select public.org_can(org_id, 'books')));

revoke all on function public.invite_to_org(uuid, text, text, jsonb) from public, anon;
revoke all on function public.accept_org_invite(uuid) from public, anon;
revoke all on function public.update_org_member_access(uuid, uuid, text, jsonb) from public, anon;
revoke all on function public.org_roster_for_period(uuid, date, date) from public, anon;
grant execute on function public.invite_to_org(uuid, text, text, jsonb) to authenticated;
grant execute on function public.accept_org_invite(uuid) to authenticated;
grant execute on function public.update_org_member_access(uuid, uuid, text, jsonb) to authenticated;
grant execute on function public.org_roster_for_period(uuid, date, date) to authenticated;

comment on column public.org_members.access is
  'Desk pages for a dispatcher. Owner and admin always have the full desk.';
comment on column public.org_invites.access is
  'Copied onto the member when the invite is accepted.';
