-- Office can close jobs on the desk. Drivers still mark picked up.
-- Paste after 040_org_company_profile.sql. Hard-refresh the dashboard.

alter table public.orgs
  add column if not exists office_closes_jobs boolean not null default false;

comment on column public.orgs.office_closes_jobs is
  'When true, only a manager on the desk can mark delivered or failed. Drivers may still mark picked up.';

create or replace function public.update_org_close_policy(
  p_org_id uuid,
  p_office_closes_jobs boolean
)
returns void
language plpgsql
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

  update public.orgs
     set office_closes_jobs = coalesce(p_office_closes_jobs, false)
   where id = p_org_id;
end;
$$;

revoke all on function public.update_org_close_policy(uuid, boolean) from public, anon;
grant execute on function public.update_org_close_policy(uuid, boolean) to authenticated;

create or replace function public.driver_update_org_job(
  p_job_id bigint,
  p_status text,
  p_note text default '',
  p_reason text default '',
  p_photo_path text default '',
  p_signature_path text default ''
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
  v_office boolean;
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  if p_status not in ('picked_up', 'delivered', 'failed') then
    raise exception 'Status not allowed';
  end if;

  select j.assigned_user_id, j.status, coalesce(o.office_closes_jobs, false)
    into v_assigned, v_status, v_office
    from public.org_jobs j
    join public.orgs o on o.id = j.org_id
   where j.id = p_job_id;

  if v_assigned is null or v_assigned <> uid then
    raise exception 'Job not assigned to you';
  end if;
  if v_office and p_status in ('delivered', 'failed') then
    raise exception 'Office closes this job on the desk';
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
  if p_signature_path <> '' and p_signature_path not like (uid::text || '/jobs/' || p_job_id::text || '/%') then
    raise exception 'Signature path must belong to you';
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
         pod_signature_path = case
           when p_status = 'delivered' and p_signature_path <> '' then p_signature_path
           else pod_signature_path
         end,
         updated_at = now()
   where id = p_job_id;
end;
$$;

revoke all on function public.driver_update_org_job(bigint, text, text, text, text, text) from public, anon;
grant execute on function public.driver_update_org_job(bigint, text, text, text, text, text) to authenticated;
