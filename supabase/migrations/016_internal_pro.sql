-- Lifetime Pro for internal testers (no App Store purchase).
-- Grant after they create an account:
--   select public.grant_internal_pro('tester@example.com');
-- Revoke:
--   select public.revoke_internal_pro('tester@example.com');
-- Run as postgres / service_role (not from the mobile app).

create or replace function public.grant_internal_pro(tester_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
begin
  select id into uid
  from auth.users
  where lower(email) = lower(trim(tester_email));

  if uid is null then
    raise exception 'No TrekTrack account with email %', tester_email;
  end if;

  insert into public.entitlements (
    user_id, active, source, period, product_id, expires_at, updated_at
  )
  values (
    uid, true, 'manual', null, 'internal.lifetime', null, now()
  )
  on conflict (user_id) do update set
    active = true,
    source = 'manual',
    period = null,
    product_id = 'internal.lifetime',
    expires_at = null,
    updated_at = now();

  return uid;
end;
$$;

create or replace function public.revoke_internal_pro(tester_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
begin
  select id into uid
  from auth.users
  where lower(email) = lower(trim(tester_email));

  if uid is null then
    raise exception 'No TrekTrack account with email %', tester_email;
  end if;

  update public.entitlements
  set active = false, updated_at = now()
  where user_id = uid
    and source = 'manual'
    and product_id = 'internal.lifetime';

  return uid;
end;
$$;

revoke all on function public.grant_internal_pro(text) from public, anon, authenticated;
revoke all on function public.revoke_internal_pro(text) from public, anon, authenticated;
grant execute on function public.grant_internal_pro(text) to postgres, service_role;
grant execute on function public.revoke_internal_pro(text) to postgres, service_role;

comment on function public.grant_internal_pro(text) is
  'Lifetime Pro for an internal tester. They must already have signed up.';
