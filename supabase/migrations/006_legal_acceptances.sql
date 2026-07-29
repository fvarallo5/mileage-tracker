-- Log Terms + Privacy acceptance per user (latest + event history).
-- Run in Supabase SQL Editor if not applied via CLI.

create table if not exists public.legal_acceptances (
  user_id uuid primary key references auth.users (id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  accepted_at timestamptz not null default now(),
  platform text,
  app_version text,
  updated_at timestamptz not null default now()
);

comment on table public.legal_acceptances is
  'Latest Terms/Privacy acceptance recorded for each user (portable evidence).';

create table if not exists public.legal_acceptance_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  accepted_at timestamptz not null default now(),
  platform text,
  app_version text
);

create index if not exists idx_legal_acceptance_events_user_at
  on public.legal_acceptance_events (user_id, accepted_at desc);

comment on table public.legal_acceptance_events is
  'Append-only history of each acceptance (re-prompts when legal versions change).';

alter table public.legal_acceptances enable row level security;
alter table public.legal_acceptance_events enable row level security;

drop policy if exists "Users read own legal acceptance" on public.legal_acceptances;
create policy "Users read own legal acceptance"
  on public.legal_acceptances for select
  using (auth.uid() = user_id);

drop policy if exists "Users upsert own legal acceptance" on public.legal_acceptances;
create policy "Users upsert own legal acceptance"
  on public.legal_acceptances for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own legal acceptance" on public.legal_acceptances;
create policy "Users update own legal acceptance"
  on public.legal_acceptances for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users read own legal events" on public.legal_acceptance_events;
create policy "Users read own legal events"
  on public.legal_acceptance_events for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own legal events" on public.legal_acceptance_events;
create policy "Users insert own legal events"
  on public.legal_acceptance_events for insert
  with check (auth.uid() = user_id);

-- Keep account wipe in sync with new tables.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.legal_acceptance_events where user_id = uid;
  delete from public.legal_acceptances where user_id = uid;
  delete from public.trips where user_id = uid;
  delete from public.settings where user_id = uid;
  delete from public.entitlements where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;
