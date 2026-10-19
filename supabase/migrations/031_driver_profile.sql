-- Driver profile fields: number, first/last name, home address.

alter table public.profiles
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists address text not null default '';

comment on column public.profiles.first_name is 'Given name for dispatch boards.';
comment on column public.profiles.last_name is 'Family name for dispatch boards.';
comment on column public.profiles.address is 'Driver home / mailing address.';

update public.profiles
set
  first_name = case
    when coalesce(first_name, '') = '' then split_part(trim(nickname), ' ', 1)
    else first_name
  end,
  last_name = case
    when coalesce(last_name, '') = '' then trim(substr(trim(nickname), length(split_part(trim(nickname), ' ', 1)) + 1))
    else last_name
  end
where coalesce(nickname, '') <> '';

alter table public.org_members
  add column if not exists driver_number text;

comment on column public.org_members.driver_number is
  'Company-assigned driver number, unique per team.';

update public.org_members
set driver_number = null
where driver_number is not null and btrim(driver_number) = '';

create unique index if not exists idx_org_members_driver_number
  on public.org_members (org_id, driver_number)
  where driver_number is not null;

create or replace function public.update_org_driver_profile(
  p_org_id uuid,
  p_user_id uuid,
  p_driver_number text,
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_address text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  num text := nullif(btrim(coalesce(p_driver_number, '')), '');
  first_n text := btrim(coalesce(p_first_name, ''));
  last_n text := btrim(coalesce(p_last_name, ''));
  phone_n text := btrim(coalesce(p_phone, ''));
  addr text := btrim(coalesce(p_address, ''));
  display text;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_org_manager_of_org(p_org_id) then
    raise exception 'Not a team manager';
  end if;
  if not exists (
    select 1
    from public.org_members
    where org_id = p_org_id
      and user_id = p_user_id
  ) then
    raise exception 'Not on this team';
  end if;
  if char_length(first_n) > 40 or char_length(last_n) > 40 then
    raise exception 'Name is too long';
  end if;
  if char_length(coalesce(num, '')) > 12 then
    raise exception 'Driver number is too long';
  end if;
  if char_length(addr) > 200 then
    raise exception 'Address is too long';
  end if;

  display := btrim(concat_ws(' ', first_n, last_n));

  update public.org_members
  set driver_number = num
  where org_id = p_org_id
    and user_id = p_user_id;

  insert into public.profiles (user_id, first_name, last_name, nickname, phone, address, updated_at)
  values (p_user_id, first_n, last_n, display, phone_n, addr, now())
  on conflict (user_id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      nickname = excluded.nickname,
      phone = excluded.phone,
      address = excluded.address,
      updated_at = now();
end;
$$;

revoke all on function public.update_org_driver_profile(uuid, uuid, text, text, text, text, text) from public, anon;
grant execute on function public.update_org_driver_profile(uuid, uuid, text, text, text, text, text) to authenticated;
