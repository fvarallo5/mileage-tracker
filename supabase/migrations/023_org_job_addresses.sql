-- Structured pickup and delivery addresses. pickup_address / dropoff_address
-- stay as the composed line the phone and Maps link already read.

alter table public.org_jobs
  add column if not exists pickup_line1 text not null default '',
  add column if not exists pickup_line2 text not null default '',
  add column if not exists pickup_city text not null default '',
  add column if not exists pickup_state text not null default '',
  add column if not exists pickup_zip text not null default '',
  add column if not exists dropoff_line1 text not null default '',
  add column if not exists dropoff_line2 text not null default '',
  add column if not exists dropoff_city text not null default '',
  add column if not exists dropoff_state text not null default '',
  add column if not exists dropoff_zip text not null default '';

comment on column public.org_jobs.pickup_address is
  'Composed pickup address for the phone summary and Maps. Written by the dashboard from the structured lines.';
comment on column public.org_jobs.dropoff_address is
  'Composed delivery address for the phone summary and Maps.';
