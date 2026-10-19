-- Weekly / monthly odometer (backfill) logs. Not GPS trips.
-- Business miles count toward reports and the tax workbook.

create table if not exists public.odometer_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  period_type text not null check (period_type in ('weekly', 'monthly')),
  start_date date not null,
  end_date date not null,
  odo_start numeric(12, 1),
  odo_end numeric(12, 1),
  miles numeric(12, 2) not null check (miles >= 0),
  personal_miles numeric(12, 2) not null default 0 check (personal_miles >= 0),
  notes text not null default '',
  overlap_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index if not exists idx_odometer_logs_user_end
  on public.odometer_logs (user_id, end_date desc, id desc);

comment on table public.odometer_logs is
  'Contractor backfill: weekly/monthly odometer or typed miles, with optional files.';

alter table public.odometer_logs enable row level security;

drop policy if exists "Users read own odometer logs" on public.odometer_logs;
create policy "Users read own odometer logs"
  on public.odometer_logs for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own odometer logs" on public.odometer_logs;
create policy "Users insert own odometer logs"
  on public.odometer_logs for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own odometer logs" on public.odometer_logs;
create policy "Users update own odometer logs"
  on public.odometer_logs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own odometer logs" on public.odometer_logs;
create policy "Users delete own odometer logs"
  on public.odometer_logs for delete
  using (auth.uid() = user_id);

create table if not exists public.odometer_log_files (
  id bigint generated always as identity primary key,
  log_id bigint not null references public.odometer_logs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  mime text not null default 'image/jpeg',
  kind text not null default 'support'
    check (kind in ('odo_start', 'odo_end', 'support')),
  created_at timestamptz not null default now()
);

create index if not exists idx_odometer_log_files_log
  on public.odometer_log_files (log_id, id);

alter table public.odometer_log_files enable row level security;

drop policy if exists "Users read own odometer files" on public.odometer_log_files;
create policy "Users read own odometer files"
  on public.odometer_log_files for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own odometer files" on public.odometer_log_files;
create policy "Users insert own odometer files"
  on public.odometer_log_files for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own odometer files" on public.odometer_log_files;
create policy "Users delete own odometer files"
  on public.odometer_log_files for delete
  using (auth.uid() = user_id);

create or replace function public.delete_own_odometer_logs()
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

  delete from storage.objects
  where bucket_id = 'receipts'
    and name like uid::text || '/odo_logs/%';

  delete from public.odometer_logs where user_id = uid;
end;
$$;

grant execute on function public.delete_own_odometer_logs() to authenticated;

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

  perform public.delete_own_odometer_logs();
  perform public.delete_own_expenses();
  perform public.delete_own_period_earnings();

  delete from public.work_shifts where user_id = uid;
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
