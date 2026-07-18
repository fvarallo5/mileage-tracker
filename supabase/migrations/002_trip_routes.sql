-- GPS route storage for map visualization (sparse points only — no extra sampling).
-- Run in Supabase SQL Editor if not applied via CLI.

alter table public.trips
  add column if not exists start_lat double precision,
  add column if not exists start_lng double precision,
  add column if not exists end_lat double precision,
  add column if not exists end_lng double precision,
  add column if not exists route jsonb not null default '[]'::jsonb;

comment on column public.trips.route is
  'Sparse [[lat,lng],...] samples from GPS trip; empty for manual/import.';
