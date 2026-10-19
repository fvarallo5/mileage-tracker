-- Public tracking link for one job. The token is the secret.
-- Returns status, towns, and an arrival origin only after pickup.
-- Does not return pay, notes, phones, or the customer account.

alter table public.org_jobs
  add column if not exists tracking_token uuid;

update public.org_jobs
   set tracking_token = gen_random_uuid()
 where tracking_token is null;

alter table public.org_jobs
  alter column tracking_token set default gen_random_uuid();

create unique index if not exists idx_org_jobs_tracking_token
  on public.org_jobs (tracking_token);

comment on column public.org_jobs.tracking_token is
  'Unguessable id for the customer tracking link. Not a login.';

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
  driver_lng double precision
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
    end
  from public.org_jobs j
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
