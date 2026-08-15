-- Wall-clock start/end for GPS (and optional manual) trips.
-- created_at remains insert time; these reflect the drive itself.

alter table public.trips
  add column if not exists started_at timestamptz,
  add column if not exists ended_at timestamptz;

comment on column public.trips.started_at is
  'When GPS tracking began (or trip start if known).';
comment on column public.trips.ended_at is
  'When GPS tracking ended (or trip end if known).';
