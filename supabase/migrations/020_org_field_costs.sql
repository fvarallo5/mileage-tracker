-- Team dashboard: manager-read field costs for a period.
-- Drivers still create/edit expenses on the phone.

create or replace function public.org_period_expenses(
  p_org_id uuid,
  p_start date,
  p_end date
)
returns table (
  expense_id bigint,
  user_id uuid,
  email text,
  nickname text,
  expense_date date,
  amount numeric,
  merchant text,
  category text,
  notes text,
  has_receipt boolean
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
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;

  return query
  select
    e.id,
    e.user_id,
    u.email::text,
    coalesce(p.nickname, ''),
    e.date,
    e.amount,
    e.merchant,
    e.category,
    e.notes,
    (e.receipt_path is not null and length(trim(e.receipt_path)) > 0)
  from public.expenses e
  join public.org_members m
    on m.user_id = e.user_id
   and m.org_id = p_org_id
  join auth.users u on u.id = e.user_id
  left join public.profiles p on p.user_id = e.user_id
  where e.date >= p_start
    and e.date <= p_end
  order by e.date desc, e.id desc
  limit 2000;
end;
$$;

revoke all on function public.org_period_expenses(uuid, date, date) from public, anon;
grant execute on function public.org_period_expenses(uuid, date, date) to authenticated;
