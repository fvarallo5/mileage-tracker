-- Team name and default invoice terms. 038 is already on live. Paste this file next.
-- Hard-refresh the dashboard so PostgREST sees default_terms.

alter table public.orgs
  add column if not exists default_terms text not null default 'Net 30';

comment on column public.orgs.default_terms is
  'Default payment terms copied onto a new customer account.';

create or replace function public.update_org_identity(
  p_org_id uuid,
  p_name text,
  p_default_terms text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_terms text := btrim(coalesce(p_default_terms, 'Net 30'));
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
  update public.orgs
  set name = v_name,
      default_terms = v_terms
  where id = p_org_id;
end;
$$;

revoke all on function public.update_org_identity(uuid, text, text) from public, anon;
grant execute on function public.update_org_identity(uuid, text, text) to authenticated;
