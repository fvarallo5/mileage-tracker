-- Business vs personal purpose for tax-ready mileage.
-- Run in Supabase SQL Editor if not applied via CLI.

alter table public.trips
  add column if not exists is_business boolean not null default true;

comment on column public.trips.is_business is
  'True = deductible business miles; false = personal (excluded from tax totals).';

create index if not exists idx_trips_user_business_date
  on public.trips (user_id, is_business, date desc);
