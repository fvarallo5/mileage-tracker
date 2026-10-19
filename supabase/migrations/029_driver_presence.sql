-- Foreground heartbeat so dispatch can see who has the phone app open.

alter table public.profiles
  add column if not exists last_seen_at timestamptz;

comment on column public.profiles.last_seen_at is
  'Last time the TrekTrack phone app was in the foreground. Null until the next IPA with presence.';

create or replace function public.touch_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.profiles (user_id, last_seen_at)
  values (uid, now())
  on conflict (user_id) do update
    set last_seen_at = now();
end;
$$;

revoke all on function public.touch_presence() from public, anon;
grant execute on function public.touch_presence() to authenticated;
