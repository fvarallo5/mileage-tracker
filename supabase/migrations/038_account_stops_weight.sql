-- Account charge numbers, saved pickup/delivery stops, job pieces/weight, org weight unit.
-- 037 is already on live. Paste this file next. Hard-refresh the dashboard so PostgREST sees the columns.

alter table public.org_customers
  add column if not exists charge_number text not null default '',
  add column if not exists pickup_name text not null default '',
  add column if not exists pickup_line1 text not null default '',
  add column if not exists pickup_line2 text not null default '',
  add column if not exists pickup_city text not null default '',
  add column if not exists pickup_state text not null default '',
  add column if not exists pickup_zip text not null default '',
  add column if not exists pickup_phone text not null default '',
  add column if not exists pickup_email text not null default '',
  add column if not exists dropoff_name text not null default '',
  add column if not exists dropoff_line1 text not null default '',
  add column if not exists dropoff_line2 text not null default '',
  add column if not exists dropoff_city text not null default '',
  add column if not exists dropoff_state text not null default '',
  add column if not exists dropoff_zip text not null default '',
  add column if not exists dropoff_phone text not null default '',
  add column if not exists dropoff_email text not null default '';

alter table public.org_customers drop constraint if exists org_customers_charge_digits;
alter table public.org_customers
  add constraint org_customers_charge_digits
  check (charge_number = '' or charge_number ~ '^[0-9]{4,5}$');

create unique index if not exists org_customers_charge_unique
  on public.org_customers (org_id, charge_number)
  where charge_number <> '';

comment on column public.org_customers.charge_number is
  '4 or 5 digit shipper code used on the job form. Unique per team when set.';

alter table public.orgs
  add column if not exists weight_unit text not null default 'lb';

alter table public.orgs drop constraint if exists orgs_weight_unit_ok;
alter table public.orgs
  add constraint orgs_weight_unit_ok
  check (weight_unit in ('lb', 'kg'));

comment on column public.orgs.weight_unit is
  'Default job weight unit. lb unless the office picks kg in Settings.';

alter table public.org_jobs
  add column if not exists item_count integer,
  add column if not exists weight_value numeric,
  add column if not exists weight_unit text;

alter table public.org_jobs drop constraint if exists org_jobs_item_count_ok;
alter table public.org_jobs
  add constraint org_jobs_item_count_ok
  check (item_count is null or item_count >= 0);

alter table public.org_jobs drop constraint if exists org_jobs_weight_value_ok;
alter table public.org_jobs
  add constraint org_jobs_weight_value_ok
  check (weight_value is null or weight_value >= 0);

alter table public.org_jobs drop constraint if exists org_jobs_weight_unit_ok;
alter table public.org_jobs
  add constraint org_jobs_weight_unit_ok
  check (weight_unit is null or weight_unit in ('lb', 'kg'));

comment on column public.org_jobs.item_count is
  'Piece count on the job. Null means not entered.';
comment on column public.org_jobs.weight_value is
  'Weight as entered. Unit is weight_unit on the same row.';

create or replace function public.update_org_weight_unit(
  p_org_id uuid,
  p_weight_unit text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  unit text := lower(btrim(coalesce(p_weight_unit, 'lb')));
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if unit not in ('lb', 'kg') then
    raise exception 'Weight unit must be lb or kg';
  end if;
  update public.orgs
  set weight_unit = unit
  where id = p_org_id;
end;
$$;

revoke all on function public.update_org_weight_unit(uuid, text) from public, anon;
grant execute on function public.update_org_weight_unit(uuid, text) to authenticated;
