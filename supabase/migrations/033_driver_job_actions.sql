-- Driver closes their own job: picked up, delivered (photo + note), or couldn't deliver.
-- 032 is already live. Paste this next. Managers can read the delivery photo.

alter table public.org_jobs
  add column if not exists pod_photo_path text not null default '';

comment on column public.org_jobs.pod_photo_path is
  'Receipts-bucket path of the delivery photo. Empty until the driver delivers.';

create or replace function public.driver_update_org_job(
  p_job_id bigint,
  p_status text,
  p_note text default '',
  p_reason text default '',
  p_photo_path text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_assigned uuid;
  v_status text;
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  if p_status not in ('picked_up', 'delivered', 'failed') then
    raise exception 'Status not allowed';
  end if;

  select assigned_user_id, status
    into v_assigned, v_status
    from public.org_jobs
   where id = p_job_id;

  if v_assigned is null or v_assigned <> uid then
    raise exception 'Job not assigned to you';
  end if;
  if v_status not in ('open', 'picked_up') then
    raise exception 'Job is already closed';
  end if;
  if p_status = 'picked_up' and v_status <> 'open' then
    raise exception 'Job is already picked up';
  end if;
  if p_photo_path <> '' and p_photo_path not like (uid::text || '/jobs/' || p_job_id::text || '/%') then
    raise exception 'Photo path must belong to you';
  end if;

  update public.org_jobs
     set status = p_status,
         pod_note = case
           when p_status = 'delivered' then coalesce(p_note, '')
           else pod_note
         end,
         failure_reason = case
           when p_status = 'failed' then coalesce(p_reason, '')
           else failure_reason
         end,
         pod_photo_path = case
           when p_status = 'delivered' and p_photo_path <> '' then p_photo_path
           else pod_photo_path
         end,
         updated_at = now()
   where id = p_job_id;
end;
$$;

revoke all on function public.driver_update_org_job(bigint, text, text, text, text) from public, anon;
grant execute on function public.driver_update_org_job(bigint, text, text, text, text) to authenticated;

create or replace function public.org_job_miles(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  job_id bigint,
  miles numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;

  return query
  select t.job_id, sum(t.miles)
    from public.trips t
    join public.org_members m
      on m.user_id = t.user_id
     and m.org_id = p_org_id
   where t.job_id is not null
     and t.date >= p_start
     and t.date <= p_end
   group by t.job_id;
end;
$$;

revoke all on function public.org_job_miles(uuid, date, date) from public, anon;
grant execute on function public.org_job_miles(uuid, date, date) to authenticated;

drop policy if exists "Managers read member receipts" on storage.objects;
create policy "Managers read member receipts"
  on storage.objects for select
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
    and public.is_org_manager_of(((storage.foldername(name))[1])::uuid)
  );
