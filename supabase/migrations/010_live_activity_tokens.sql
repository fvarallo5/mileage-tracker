-- ActivityKit push-to-start tokens (iOS 17.2+) for background Live Activities.

create table if not exists public.live_activity_tokens (
  user_id uuid primary key references auth.users (id) on delete cascade,
  push_to_start_token text not null,
  platform text not null default 'ios' check (platform in ('ios')),
  updated_at timestamptz not null default now()
);

comment on table public.live_activity_tokens is
  'Per-user ActivityKit push-to-start token for starting TrekTrack Live Activities while locked.';

alter table public.live_activity_tokens enable row level security;

drop policy if exists "Users read own live_activity_tokens" on public.live_activity_tokens;
create policy "Users read own live_activity_tokens"
  on public.live_activity_tokens for select
  using (auth.uid() = user_id);

drop policy if exists "Users upsert own live_activity_tokens" on public.live_activity_tokens;
create policy "Users upsert own live_activity_tokens"
  on public.live_activity_tokens for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own live_activity_tokens" on public.live_activity_tokens;
create policy "Users update own live_activity_tokens"
  on public.live_activity_tokens for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own live_activity_tokens" on public.live_activity_tokens;
create policy "Users delete own live_activity_tokens"
  on public.live_activity_tokens for delete
  using (auth.uid() = user_id);
