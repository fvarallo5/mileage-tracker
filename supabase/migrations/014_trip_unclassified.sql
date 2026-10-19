-- Allow unclassified trips (null purpose) until the driver swipes Business / Personal.
-- Existing rows stay true (already treated as business).

alter table public.trips
  alter column is_business drop not null;

alter table public.trips
  alter column is_business drop default;

alter table public.trips
  alter column is_business set default null;

comment on column public.trips.is_business is
  'true = deductible business miles; false = personal; null = unclassified (needs swipe).';
