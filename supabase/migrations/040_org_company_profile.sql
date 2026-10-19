-- Company desk identity. 039 is already on live. Paste this file next.
-- Hard-refresh the dashboard so PostgREST sees the new columns.

alter table public.orgs
  add column if not exists phone text not null default '',
  add column if not exists dispatch_email text not null default '',
  add column if not exists address_line1 text not null default '',
  add column if not exists address_city text not null default '',
  add column if not exists address_state text not null default '',
  add column if not exists address_zip text not null default '',
  add column if not exists timezone text not null default 'America/New_York',
  add column if not exists job_prefix text not null default '';

alter table public.orgs drop constraint if exists orgs_timezone_ok;
alter table public.orgs
  add constraint orgs_timezone_ok check (timezone in (
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Phoenix',
    'America/Los_Angeles',
    'America/Anchorage',
    'Pacific/Honolulu'
  ));

alter table public.orgs drop constraint if exists orgs_job_prefix_ok;
alter table public.orgs
  add constraint orgs_job_prefix_ok check (char_length(job_prefix) <= 12);

comment on column public.orgs.phone is
  'Desk phone shown on the public tracking page.';
comment on column public.orgs.dispatch_email is
  'Office email for this company. Not shown on the tracking page.';
comment on column public.orgs.address_line1 is
  'Company street address.';
comment on column public.orgs.timezone is
  'IANA zone for the desk clock and after-hours window.';
comment on column public.orgs.job_prefix is
  'Prefill on a new job number, for example GT-.';

drop function if exists public.update_org_identity(uuid, text, text);

create or replace function public.update_org_identity(
  p_org_id uuid,
  p_name text,
  p_default_terms text,
  p_phone text default '',
  p_dispatch_email text default '',
  p_address_line1 text default '',
  p_address_city text default '',
  p_address_state text default '',
  p_address_zip text default '',
  p_timezone text default 'America/New_York',
  p_job_prefix text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_terms text := btrim(coalesce(p_default_terms, 'Net 30'));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_email text := lower(btrim(coalesce(p_dispatch_email, '')));
  v_line1 text := btrim(coalesce(p_address_line1, ''));
  v_city text := btrim(coalesce(p_address_city, ''));
  v_state text := upper(btrim(coalesce(p_address_state, '')));
  v_zip text := btrim(coalesce(p_address_zip, ''));
  v_tz text := btrim(coalesce(p_timezone, 'America/New_York'));
  v_prefix text := btrim(coalesce(p_job_prefix, ''));
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if v_name = '' then
    raise exception 'Team name is required';
  end if;
  if v_terms = '' then
    v_terms := 'Net 30';
  end if;
  if v_tz = '' then
    v_tz := 'America/New_York';
  end if;
  v_prefix := regexp_replace(v_prefix, '[^A-Za-z0-9-]', '', 'g');
  v_prefix := left(v_prefix, 12);

  update public.orgs
  set name = v_name,
      default_terms = v_terms,
      phone = v_phone,
      dispatch_email = v_email,
      address_line1 = v_line1,
      address_city = v_city,
      address_state = v_state,
      address_zip = v_zip,
      timezone = v_tz,
      job_prefix = v_prefix
  where id = p_org_id;
end;
$$;

revoke all on function public.update_org_identity(
  uuid, text, text, text, text, text, text, text, text, text, text
) from public, anon;
grant execute on function public.update_org_identity(
  uuid, text, text, text, text, text, text, text, text, text, text
) to authenticated;

drop function if exists public.track_job(uuid);

create or replace function public.track_job(p_token uuid)
returns table (
  status text,
  job_number text,
  pickup_city text,
  dropoff_city text,
  pickup_address text,
  dropoff_address text,
  pickup_time time,
  dropoff_time time,
  driver_lat double precision,
  driver_lng double precision,
  company_name text,
  company_phone text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_token is null then
    return;
  end if;

  return query
  select
    j.status,
    j.job_number,
    coalesce(j.pickup_city, ''),
    coalesce(j.dropoff_city, ''),
    coalesce(j.pickup_address, ''),
    coalesce(j.dropoff_address, ''),
    coalesce(j.pickup_time, j.job_time),
    j.dropoff_time,
    case
      when j.status = 'picked_up' then loc.lat
      else null
    end,
    case
      when j.status = 'picked_up' then loc.lng
      else null
    end,
    coalesce(o.name, 'TrekTrack'),
    coalesce(o.phone, '')
  from public.org_jobs j
  join public.orgs o on o.id = j.org_id
  left join lateral (
    select
      coalesce(t.end_lat, t.start_lat) as lat,
      coalesce(t.end_lng, t.start_lng) as lng
    from public.trips t
    where t.user_id = j.assigned_user_id
      and (t.job_id = j.id or t.date = j.job_date)
      and coalesce(t.end_lat, t.start_lat) is not null
      and coalesce(t.end_lng, t.start_lng) is not null
    order by
      case when t.job_id = j.id then 0 else 1 end,
      t.date desc,
      t.id desc
    limit 1
  ) loc on true
  where j.tracking_token = p_token
  limit 1;
end;
$$;

revoke all on function public.track_job(uuid) from public;
grant execute on function public.track_job(uuid) to anon, authenticated;
