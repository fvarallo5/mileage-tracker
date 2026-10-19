-- Allow daily / biweekly earnings cadences (Field Costs redesign).
-- Existing weekly / monthly / annual rows remain valid.

alter table public.period_earnings
  drop constraint if exists period_earnings_period_type_check;

alter table public.period_earnings
  add constraint period_earnings_period_type_check
  check (period_type in ('daily', 'weekly', 'biweekly', 'monthly', 'annual'));

comment on column public.period_earnings.period_type is
  'daily | weekly | biweekly | monthly | annual — cadence of the logged earnings total.';
