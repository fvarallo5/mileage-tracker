-- TrekTrack expenses + receipt storage (no bank sync).
-- Run in Supabase SQL Editor after earlier migrations.

-- ---------------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------------
create table if not exists public.expenses (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'USD',
  merchant text not null default '',
  category text not null default 'other',
  notes text not null default '',
  trip_id bigint references public.trips (id) on delete set null,
  receipt_path text,
  receipt_mime text,
  ocr_raw text,
  ocr_confidence numeric(5, 4),
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_expenses_user_date
  on public.expenses (user_id, date desc, id desc);

create index if not exists idx_expenses_user_trip
  on public.expenses (user_id, trip_id)
  where trip_id is not null;

comment on table public.expenses is
  'User expense log with optional receipt image/PDF path in Storage.';
comment on column public.expenses.source is
  'manual | ocr | upload — how the expense was primarily created.';
comment on column public.expenses.receipt_path is
  'Storage object path in bucket receipts: {user_id}/{expense_id}/...';

alter table public.expenses enable row level security;

drop policy if exists "Users read own expenses" on public.expenses;
create policy "Users read own expenses"
  on public.expenses for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own expenses" on public.expenses;
create policy "Users insert own expenses"
  on public.expenses for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own expenses" on public.expenses;
create policy "Users update own expenses"
  on public.expenses for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own expenses" on public.expenses;
create policy "Users delete own expenses"
  on public.expenses for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Storage: receipts bucket (private; path must start with auth.uid())
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts',
  'receipts',
  false,
  10485760, -- 10 MB
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
    'application/pdf'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users read own receipts" on storage.objects;
create policy "Users read own receipts"
  on storage.objects for select
  using (
    bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users upload own receipts" on storage.objects;
create policy "Users upload own receipts"
  on storage.objects for insert
  with check (
    bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users update own receipts" on storage.objects;
create policy "Users update own receipts"
  on storage.objects for update
  using (
    bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users delete own receipts" on storage.objects;
create policy "Users delete own receipts"
  on storage.objects for delete
  using (
    bucket_id = 'receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ---------------------------------------------------------------------------
-- Account wipe: remove expenses + receipt objects for caller
-- ---------------------------------------------------------------------------
create or replace function public.delete_own_expenses()
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

  -- Remove storage objects under receipts/{uid}/
  delete from storage.objects
  where bucket_id = 'receipts'
    and name like uid::text || '/%';

  delete from public.expenses where user_id = uid;
end;
$$;

grant execute on function public.delete_own_expenses() to authenticated;

-- Hook into delete_own_account if present (best-effort; re-define cascade).
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

  delete from public.trips where user_id = uid;
  delete from public.settings where user_id = uid;
  delete from public.entitlements where user_id = uid;
  delete from public.legal_acceptance_events where user_id = uid;
  delete from public.legal_acceptances where user_id = uid;

  delete from auth.users where id = uid;
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
