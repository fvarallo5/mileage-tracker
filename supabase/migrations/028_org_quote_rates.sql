-- Team quote: minimum fare + per-mile charge for dispatcher estimates.

alter table public.orgs
  add column if not exists quote_per_mile numeric not null default 3.00;

alter table public.orgs
  add column if not exists quote_minimum numeric not null default 35.00;

comment on column public.orgs.quote_per_mile is
  'Retail dollars per driving mile used to quote a job.';
comment on column public.orgs.quote_minimum is
  'Minimum fare in dollars. Quote is the greater of this and miles × quote_per_mile.';

create or replace function public.update_org_quote_rates(
  p_org_id uuid,
  p_quote_per_mile numeric,
  p_quote_minimum numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  per_mile numeric := p_quote_per_mile;
  minimum numeric := p_quote_minimum;
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

  update public.orgs
  set quote_per_mile = round(per_mile, 3),
      quote_minimum = round(minimum, 2)
  where id = p_org_id;
end;
$$;

revoke all on function public.update_org_quote_rates(uuid, numeric, numeric) from public, anon;
grant execute on function public.update_org_quote_rates(uuid, numeric, numeric) to authenticated;
