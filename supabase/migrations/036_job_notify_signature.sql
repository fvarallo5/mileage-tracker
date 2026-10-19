-- Stop emails, service add-on, and a delivery signature next to the photo.
-- 035 is already live. Paste this file in the SQL editor, then hard-refresh the dashboard.
-- IPA 45 still calls this RPC with five named args; the sixth defaults to empty.

alter table public.org_jobs
  add column if not exists pickup_email text not null default '',
  add column if not exists dropoff_email text not null default '',
  add column if not exists service_level text not null default '',
  add column if not exists service_addon numeric,
  add column if not exists pod_signature_path text not null default '';

alter table public.org_jobs drop constraint if exists org_jobs_service_level_ok;
alter table public.org_jobs
  add constraint org_jobs_service_level_ok
  check (service_level in ('', 'same_day', 'rush', 'wait', 'extra_piece'));

alter table public.org_jobs drop constraint if exists org_jobs_service_addon_ok;
alter table public.org_jobs
  add constraint org_jobs_service_addon_ok
  check (service_addon is null or service_addon >= 0);

comment on column public.org_jobs.pickup_email is
  'Optional pickup contact for the tracking link and status mail.';
comment on column public.org_jobs.dropoff_email is
  'Optional delivery contact for the tracking link and status mail.';
comment on column public.org_jobs.service_level is
  'Typed extra on the job: same_day, rush, wait, extra_piece, or blank for standard.';
comment on column public.org_jobs.service_addon is
  'Dollar add-on after weekend and after-hours multipliers. Ignored when quote_manual.';
comment on column public.org_jobs.pod_signature_path is
  'Receipts-bucket path of the delivery signature. Empty until the driver signs.';

drop function if exists public.driver_update_org_job(bigint, text, text, text, text);

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
