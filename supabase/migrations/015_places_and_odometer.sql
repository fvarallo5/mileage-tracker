-- Saved commute places (max 3 enforced in app) + optional odometer photos on trips.

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null default 'Place',
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null default 150 check (radius_m >= 50 and radius_m <= 500),
  created_at timestamptz not null default now()
);

create index if not exists idx_places_user on public.places (user_id, created_at);

comment on table public.places is
  'Home / garage / repeat stops. Trips starting or ending here auto-mark Personal.';

alter table public.places enable row level security;

drop policy if exists "Users read own places" on public.places;
create policy "Users read own places"
  on public.places for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own places" on public.places;
create policy "Users insert own places"
  on public.places for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own places" on public.places;
create policy "Users update own places"
  on public.places for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own places" on public.places;
create policy "Users delete own places"
  on public.places for delete
  using (auth.uid() = user_id);

alter table public.trips
  add column if not exists odo_start_path text,
  add column if not exists odo_end_path text;

comment on column public.trips.odo_start_path is
  'Storage path in receipts bucket for start odometer photo.';
comment on column public.trips.odo_end_path is
  'Storage path in receipts bucket for end odometer photo.';

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
