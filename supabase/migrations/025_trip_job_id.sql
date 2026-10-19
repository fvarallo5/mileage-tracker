-- Link a driver's trip to a completed dispatch job.
-- Assignee may mark their job done. Trips.job_id must be their own assignment.

alter table public.trips
  add column if not exists job_id bigint references public.org_jobs (id) on delete set null;

create index if not exists idx_trips_job_id on public.trips (job_id)
  where job_id is not null;

create or replace function public.trips_job_must_be_own()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_assigned uuid;
begin
  if new.job_id is null then
    return new;
  end if;
  select assigned_user_id into v_assigned
    from public.org_jobs
   where id = new.job_id;
  if v_assigned is null or v_assigned <> new.user_id then
    raise exception 'job_id must be a job assigned to this driver';
  end if;
  return new;
end;
$$;

drop trigger if exists trips_job_must_be_own on public.trips;
create trigger trips_job_must_be_own
  before insert or update of job_id on public.trips
  for each row execute function public.trips_job_must_be_own();

create or replace function public.complete_org_job(p_job_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  update public.org_jobs
     set status = 'done', updated_at = now()
   where id = p_job_id
     and assigned_user_id = uid
     and status = 'open';
  if not found then
    raise exception 'Job not found or already closed';
  end if;
end;
$$;

revoke all on function public.complete_org_job(bigint) from public, anon;
grant execute on function public.complete_org_job(bigint) to authenticated;

comment on column public.trips.job_id is
  'Optional org_jobs row this drive belongs to. Driver-owned; must match assigned_user_id.';
