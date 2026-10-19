-- Punch-clock shifts (hourly mode). Independent of GPS trips.

create table if not exists public.work_shifts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint work_shifts_ended_after_start
    check (ended_at is null or ended_at >= started_at)
);

create index if not exists idx_work_shifts_user_start
  on public.work_shifts (user_id, started_at desc);

create unique index if not exists idx_work_shifts_one_open
  on public.work_shifts (user_id)
  where ended_at is null;

comment on table public.work_shifts is
  'Clock-in / clock-out envelope. GPS trips still log miles inside the shift.';

alter table public.work_shifts enable row level security;

drop policy if exists "Users read own work shifts" on public.work_shifts;
create policy "Users read own work shifts"
  on public.work_shifts for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own work shifts" on public.work_shifts;
create policy "Users insert own work shifts"
  on public.work_shifts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own work shifts" on public.work_shifts;
create policy "Users update own work shifts"
  on public.work_shifts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own work shifts" on public.work_shifts;
create policy "Users delete own work shifts"
  on public.work_shifts for delete
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.work_shifts to authenticated;
grant usage, select on sequence public.work_shifts_id_seq to authenticated;

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
