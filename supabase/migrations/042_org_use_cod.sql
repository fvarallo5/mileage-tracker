-- Desk can hide cash-on-delivery on the job form.
-- Paste after 041_office_closes_jobs.sql. Hard-refresh the dashboard.

alter table public.orgs
  add column if not exists use_cod boolean not null default false;

comment on column public.orgs.use_cod is
  'When true, job forms show cash on delivery. When false, those fields stay hidden.';

create or replace function public.update_org_cod_policy(
  p_org_id uuid,
  p_use_cod boolean
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
     set use_cod = coalesce(p_use_cod, false)
   where id = p_org_id;
end;
$$;

revoke all on function public.update_org_cod_policy(uuid, boolean) from public, anon;
grant execute on function public.update_org_cod_policy(uuid, boolean) to authenticated;
