-- Team dispatch jobs. Managers CRUD; assigned driver can read own rows.

create table if not exists public.org_jobs (
  id bigint generated always as identity primary key,
  org_id uuid not null references public.orgs (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  job_number text not null,
  job_date date not null,
  job_time time,
  pickup_name text not null default '',
  pickup_address text not null default '',
  pickup_phone text not null default '',
  dropoff_name text not null default '',
  dropoff_address text not null default '',
  dropoff_phone text not null default '',
  details text not null default '',
  notes text not null default '',
  assigned_user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'done', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_org_jobs_org_date
  on public.org_jobs (org_id, job_date desc, id desc);

create index if not exists idx_org_jobs_assigned
  on public.org_jobs (assigned_user_id, job_date desc);

alter table public.org_jobs enable row level security;

drop policy if exists "Managers and assignee read jobs" on public.org_jobs;
create policy "Managers and assignee read jobs"
  on public.org_jobs for select
  using (
    public.is_org_manager_of_org(org_id)
    or assigned_user_id = auth.uid()
  );

drop policy if exists "Managers insert jobs" on public.org_jobs;
create policy "Managers insert jobs"
  on public.org_jobs for insert
  with check (public.is_org_manager_of_org(org_id));

drop policy if exists "Managers update jobs" on public.org_jobs;
create policy "Managers update jobs"
  on public.org_jobs for update
  using (public.is_org_manager_of_org(org_id))
  with check (public.is_org_manager_of_org(org_id));

drop policy if exists "Managers delete jobs" on public.org_jobs;
create policy "Managers delete jobs"
  on public.org_jobs for delete
  using (public.is_org_manager_of_org(org_id));

grant select, insert, update, delete on public.org_jobs to authenticated;

comment on table public.org_jobs is
  'Team dispatch. Managers CRUD; assigned driver reads own rows.';
