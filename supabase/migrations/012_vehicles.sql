-- Multiple vehicles per user. Nickname stays on public.profiles.

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  year int,
  make text not null default '',
  model text not null default '',
  color text not null default '',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vehicles_user
  on public.vehicles (user_id, is_primary desc, updated_at desc);

comment on table public.vehicles is
  'Saved vehicles for a driver; one may be marked primary.';

alter table public.vehicles enable row level security;

drop policy if exists "Users read own vehicles" on public.vehicles;
create policy "Users read own vehicles"
  on public.vehicles for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own vehicles" on public.vehicles;
create policy "Users insert own vehicles"
  on public.vehicles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own vehicles" on public.vehicles;
create policy "Users update own vehicles"
  on public.vehicles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own vehicles" on public.vehicles;
create policy "Users delete own vehicles"
  on public.vehicles for delete
  using (auth.uid() = user_id);

-- Migrate single vehicle columns from profiles into vehicles (once).
insert into public.vehicles (user_id, year, make, model, color, is_primary)
select
  p.user_id,
  p.vehicle_year,
  coalesce(nullif(trim(p.vehicle_make), ''), 'Unknown'),
  coalesce(nullif(trim(p.vehicle_model), ''), 'Unknown'),
  coalesce(p.vehicle_color, ''),
  true
from public.profiles p
where (
    (p.vehicle_make is not null and trim(p.vehicle_make) <> '')
    or (p.vehicle_model is not null and trim(p.vehicle_model) <> '')
    or p.vehicle_year is not null
  )
  and not exists (
    select 1 from public.vehicles v where v.user_id = p.user_id
  );

-- Extend account wipe.
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

grant execute on function public.delete_own_account() to authenticated;
