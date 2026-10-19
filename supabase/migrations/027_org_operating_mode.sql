-- Org product mode: fleet dispatch vs reimbursement accountant.

alter table public.orgs
  add column if not exists operating_mode text not null default 'fleet';

alter table public.orgs drop constraint if exists orgs_operating_mode_check;
alter table public.orgs
  add constraint orgs_operating_mode_check
  check (operating_mode in ('fleet', 'reimbursement'));

comment on column public.orgs.operating_mode is
  'fleet = dispatcher job board; reimbursement = employee miles/receipts/tolls for accounting.';

drop function if exists public.create_org(text, text, text, text);
drop function if exists public.create_org(text);

create or replace function public.create_org(
  org_name text,
  p_job_style text default 'delivery',
  p_company_kind text default 'other',
  p_default_pay_type text default 'contractor',
  p_operating_mode text default 'fleet'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  oid uuid;
  style text := lower(trim(p_job_style));
  kind text := lower(trim(p_company_kind));
  pay text := lower(trim(p_default_pay_type));
  mode text := lower(trim(p_operating_mode));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if exists (select 1 from public.org_members where user_id = uid) then
    raise exception 'Already in a team';
  end if;
  if style not in ('service', 'delivery') then
    style := 'delivery';
  end if;
  if kind not in ('hvac', 'plumbing', 'landscaping', 'delivery', 'other') then
    kind := 'other';
  end if;
  if pay not in ('hourly', 'reimbursement', 'contractor') then
    pay := 'contractor';
  end if;
  if mode not in ('fleet', 'reimbursement') then
    mode := 'fleet';
  end if;
  if mode = 'reimbursement' then
    pay := 'reimbursement';
  end if;

  insert into public.orgs (name, created_by, job_style, company_kind, default_pay_type, operating_mode)
  values (trim(org_name), uid, style, kind, pay, mode)
  returning id into oid;

  insert into public.org_members (org_id, user_id, role, pay_type)
  values (oid, uid, 'owner', pay);

  return oid;
end;
$$;

create or replace function public.update_org_operating_mode(
  p_org_id uuid,
  p_operating_mode text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mode text := lower(trim(p_operating_mode));
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if mode not in ('fleet', 'reimbursement') then
    raise exception 'Invalid company type';
  end if;

  update public.orgs
  set operating_mode = mode,
      default_pay_type = case
        when mode = 'reimbursement' then 'reimbursement'
        else default_pay_type
      end
  where id = p_org_id;
end;
$$;

revoke all on function public.create_org(text, text, text, text, text) from public, anon;
revoke all on function public.update_org_operating_mode(uuid, text) from public, anon;
grant execute on function public.create_org(text, text, text, text, text) to authenticated;
grant execute on function public.update_org_operating_mode(uuid, text) to authenticated;
