-- Weekly driver availability (office schedule). Independent of punch-clock work_shifts.
-- weekday matches JavaScript getDay(): 0 Sunday … 6 Saturday.
-- Paste in the SQL editor. Hard-refresh the dashboard so PostgREST sees the table.

create table if not exists public.org_driver_hours (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  weekday smallint not null,
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint org_driver_hours_weekday_ok check (weekday >= 0 and weekday <= 6),
  constraint org_driver_hours_window_ok check (end_time > start_time),
  constraint org_driver_hours_member_fk
    foreign key (org_id, user_id) references public.org_members (org_id, user_id) on delete cascade,
  constraint org_driver_hours_one_day unique (org_id, user_id, weekday)
);

create index if not exists idx_org_driver_hours_org_day
  on public.org_driver_hours (org_id, weekday);

create index if not exists idx_org_driver_hours_user
  on public.org_driver_hours (org_id, user_id);

comment on table public.org_driver_hours is
  'Weekly availability per driver. Missing weekday means off that day. Plan uses this for coverage.';

alter table public.org_driver_hours enable row level security;

drop policy if exists "Managers read driver hours" on public.org_driver_hours;
create policy "Managers read driver hours"
  on public.org_driver_hours for select
  to authenticated
  using ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Drivers read own hours" on public.org_driver_hours;
create policy "Drivers read own hours"
  on public.org_driver_hours for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    and org_id in (select public.user_org_ids())
  );

drop policy if exists "Managers insert driver hours" on public.org_driver_hours;
create policy "Managers insert driver hours"
  on public.org_driver_hours for insert
  to authenticated
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers update driver hours" on public.org_driver_hours;
create policy "Managers update driver hours"
  on public.org_driver_hours for update
  to authenticated
  using ((select public.is_org_manager_of_org(org_id)))
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers delete driver hours" on public.org_driver_hours;
create policy "Managers delete driver hours"
  on public.org_driver_hours for delete
  to authenticated
  using ((select public.is_org_manager_of_org(org_id)));

grant select, insert, update, delete on public.org_driver_hours to authenticated;
grant usage, select on sequence public.org_driver_hours_id_seq to authenticated;
