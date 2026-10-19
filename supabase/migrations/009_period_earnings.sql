-- Period earnings totals (weekly / monthly / annual) — not per-trip tips.
-- Optional receipt/statement in the existing private `receipts` bucket.

create table if not exists public.period_earnings (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  period_type text not null check (period_type in ('weekly', 'monthly', 'annual')),
  start_date date not null,
  end_date date not null,
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'USD',
  notes text not null default '',
  receipt_path text,
  receipt_mime text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index if not exists idx_period_earnings_user_range
  on public.period_earnings (user_id, start_date desc, end_date desc);

comment on table public.period_earnings is
  'Gig / platform earnings logged for a report period (not individual trip tips).';

alter table public.period_earnings enable row level security;

drop policy if exists "Users read own period_earnings" on public.period_earnings;
create policy "Users read own period_earnings"
  on public.period_earnings for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own period_earnings" on public.period_earnings;
create policy "Users insert own period_earnings"
  on public.period_earnings for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own period_earnings" on public.period_earnings;
create policy "Users update own period_earnings"
  on public.period_earnings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own period_earnings" on public.period_earnings;
create policy "Users delete own period_earnings"
  on public.period_earnings for delete
  using (auth.uid() = user_id);

create or replace function public.delete_own_period_earnings()
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
    and name like uid::text || '/period_earnings/%';

  delete from public.period_earnings where user_id = uid;
end;
$$;

grant execute on function public.delete_own_period_earnings() to authenticated;

-- Extend account wipe when present.
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

  delete from auth.users where id = uid;
end;
$$;
