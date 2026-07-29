-- Allow signed-in users to fully delete their account from the app.
-- Run in Supabase SQL Editor if not applied via CLI.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.trips where user_id = uid;
  delete from public.settings where user_id = uid;
  delete from public.entitlements where user_id = uid;

  -- Remove auth user (cascades any remaining FKs that reference auth.users).
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
grant execute on function public.delete_own_account() to anon;

comment on function public.delete_own_account() is
  'Wipes the caller''s trips/settings/entitlements and deletes their auth user.';
