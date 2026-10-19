-- Quote vs driver pay, after-hours/weekend factors, pickup/dropoff times.

alter table public.orgs
  add column if not exists quote_weekend_mult numeric not null default 1.25,
  add column if not exists quote_after_hours_mult numeric not null default 1.25,
  add column if not exists quote_after_hours_start time not null default '18:00',
  add column if not exists quote_after_hours_end time not null default '06:00',
  add column if not exists company_take_pct numeric not null default 0.30;

comment on column public.orgs.quote_weekend_mult is
  'Multiplier applied to the auto quote when the job date is Sat/Sun.';
comment on column public.orgs.quote_after_hours_mult is
  'Multiplier applied to the auto quote when pickup is in the after-hours window.';
comment on column public.orgs.quote_after_hours_start is
  'Local time after-hours window begins. May wrap past midnight when later than end.';
comment on column public.orgs.quote_after_hours_end is
  'Local time after-hours window ends.';
comment on column public.orgs.company_take_pct is
  'Share of the quoted amount kept by the company (0.30 = 30%). Driver pay is the remainder.';

alter table public.org_jobs
  add column if not exists pickup_time time,
  add column if not exists dropoff_time time,
  add column if not exists quoted_amount numeric,
  add column if not exists driver_pay numeric,
  add column if not exists company_take numeric,
  add column if not exists company_take_pct numeric,
  add column if not exists quote_manual boolean not null default false,
  add column if not exists quote_weekend boolean not null default false,
  add column if not exists quote_after_hours boolean not null default false,
  add column if not exists series_id uuid;

update public.org_jobs
set pickup_time = job_time
where pickup_time is null and job_time is not null;

comment on column public.org_jobs.pickup_time is
  'Scheduled pickup. job_time is kept in sync for the phone board.';
comment on column public.org_jobs.dropoff_time is
  'Scheduled dropoff. Dispatcher default is pickup plus two hours.';
comment on column public.org_jobs.quoted_amount is
  'Customer quote in USD (auto from team rates, or a manual write-in).';
comment on column public.org_jobs.driver_pay is
  'Amount owed the driver: quoted_amount minus company_take.';
comment on column public.org_jobs.company_take is
  'Company share of the quoted amount in USD.';
comment on column public.org_jobs.quote_manual is
  'True when the dispatcher typed the quote instead of using team rate factors.';
comment on column public.org_jobs.series_id is
  'Shared id for weekday-recurring jobs created together.';

create index if not exists idx_org_jobs_series
  on public.org_jobs (org_id, series_id)
  where series_id is not null;

create or replace function public.update_org_quote_settings(
  p_org_id uuid,
  p_quote_per_mile numeric,
  p_quote_minimum numeric,
  p_weekend_mult numeric,
  p_after_hours_mult numeric,
  p_after_hours_start time,
  p_after_hours_end time,
  p_company_take_pct numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  per_mile numeric := p_quote_per_mile;
  minimum numeric := p_quote_minimum;
  weekend numeric := p_weekend_mult;
  after_hours numeric := p_after_hours_mult;
  take numeric := p_company_take_pct;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if per_mile is null or per_mile < 0 or per_mile > 100 then
    raise exception 'Charge per mile must be between 0 and 100';
  end if;
  if minimum is null or minimum < 0 or minimum > 10000 then
    raise exception 'Minimum fare must be between 0 and 10000';
  end if;
  if weekend is null or weekend < 1 or weekend > 5 then
    raise exception 'Weekend multiplier must be between 1 and 5';
  end if;
  if after_hours is null or after_hours < 1 or after_hours > 5 then
    raise exception 'After-hours multiplier must be between 1 and 5';
  end if;
  if p_after_hours_start is null or p_after_hours_end is null then
    raise exception 'After-hours window is required';
  end if;
  if take is null or take < 0 or take > 0.9 then
    raise exception 'Company take must be between 0 and 90 percent';
  end if;

  update public.orgs
  set quote_per_mile = round(per_mile, 3),
      quote_minimum = round(minimum, 2),
      quote_weekend_mult = round(weekend, 3),
      quote_after_hours_mult = round(after_hours, 3),
      quote_after_hours_start = p_after_hours_start,
      quote_after_hours_end = p_after_hours_end,
      company_take_pct = round(take, 4)
  where id = p_org_id;
end;
$$;

revoke all on function public.update_org_quote_settings(uuid, numeric, numeric, numeric, numeric, time, time, numeric) from public, anon;
grant execute on function public.update_org_quote_settings(uuid, numeric, numeric, numeric, numeric, time, time, numeric) to authenticated;
