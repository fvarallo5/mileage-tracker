-- Pro entitlements per user (synced from the app after store purchase / restore).
-- Run in Supabase SQL Editor if not applied via CLI.
--
-- Note: clients write their own row after a successful IAP. Full App Store /
-- Play receipt verification can be added later via an Edge Function.

create table if not exists public.entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  active boolean not null default false,
  product_id text,
  platform text,
  store_purchase_id text,
  source text not null default 'store'
    check (source in ('store', 'debug', 'server', 'manual')),
  period text
    check (period is null or period in ('monthly', 'yearly')),
  expires_at timestamptz,
  purchase_token text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.entitlements is
  'Per-user Pro access. Synced from mobile after purchase/restore; source of truth across devices.';

create index if not exists idx_entitlements_active
  on public.entitlements (active)
  where active = true;

alter table public.entitlements enable row level security;

drop policy if exists "Users read own entitlement" on public.entitlements;
create policy "Users read own entitlement"
  on public.entitlements for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own entitlement" on public.entitlements;
create policy "Users insert own entitlement"
  on public.entitlements for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own entitlement" on public.entitlements;
create policy "Users update own entitlement"
  on public.entitlements for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Optional: allow clear on sign-out flows
drop policy if exists "Users delete own entitlement" on public.entitlements;
create policy "Users delete own entitlement"
  on public.entitlements for delete
  using (auth.uid() = user_id);
