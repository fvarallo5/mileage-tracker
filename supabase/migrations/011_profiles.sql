-- Per-user profile (nickname + vehicle) for soft-launch MVP.
-- Run in Supabase SQL Editor after earlier migrations.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null default '',
  vehicle_year int,
  vehicle_make text not null default '',
  vehicle_model text not null default '',
  vehicle_color text not null default '',
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Optional driver nickname and vehicle details; local prefs are primary for offline.';

alter table public.profiles enable row level security;

drop policy if exists "Users read own profile" on public.profiles;
create policy "Users read own profile"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own profile" on public.profiles;
create policy "Users insert own profile"
  on public.profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own profile" on public.profiles;
create policy "Users delete own profile"
  on public.profiles for delete
  using (auth.uid() = user_id);

-- Extend account wipe when present (mirrors 009 + profiles).
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

  perform public.delete_own_expenses();
  perform public.delete_own_period_earnings();

  delete from public.trips where user_id = uid;
  delete from public.settings where user_id = uid;
  delete from public.entitlements where user_id = uid;
  delete from public.legal_acceptance_events where user_id = uid;
  delete from public.profiles where user_id = uid;

  delete from auth.users where id = uid;
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
