-- Mileage Tracker — Supabase schema
-- Dashboard: SQL Editor → paste this entire file → Run
-- Required: Authentication → Providers → Anonymous sign-ins → ON

-- Trips
create table if not exists public.trips (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  miles numeric(10, 2) not null check (miles > 0),
  tips numeric(10, 2) not null default 0 check (tips >= 0),
  notes text not null default '',
  source text not null default 'manual',
  created_at timestamptz not null default now()
);

create index if not exists idx_trips_user_date on public.trips (user_id, date desc);

-- Per-user settings (mileage rate)
create table if not exists public.settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  mileage_rate numeric(4, 2) not null default 0.70 check (mileage_rate > 0),
  updated_at timestamptz not null default now()
);

-- Row Level Security
alter table public.trips enable row level security;
alter table public.settings enable row level security;

create policy "Users read own trips"
  on public.trips for select
  using (auth.uid() = user_id);

create policy "Users insert own trips"
  on public.trips for insert
  with check (auth.uid() = user_id);

create policy "Users update own trips"
  on public.trips for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete own trips"
  on public.trips for delete
  using (auth.uid() = user_id);

create policy "Users read own settings"
  on public.settings for select
  using (auth.uid() = user_id);

create policy "Users insert own settings"
  on public.settings for insert
  with check (auth.uid() = user_id);

create policy "Users update own settings"
  on public.settings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Auto-create settings row for new users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.settings (user_id, mileage_rate)
  values (new.id, 0.70)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();