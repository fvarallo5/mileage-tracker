-- Owner/admin can invite with email or phone and stash member details.
-- Paste after 043. Hard-refresh the dashboard.

create or replace function public.org_normalize_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  raw text := btrim(coalesce(p_phone, ''));
  digits text;
begin
  if raw = '' then
    return null;
  end if;
  digits := regexp_replace(raw, '\D', '', 'g');
  if length(digits) = 10 then
    return '+1' || digits;
  end if;
  if length(digits) = 11 and left(digits, 1) = '1' then
    return '+' || digits;
  end if;
  if left(raw, 1) = '+' and length(digits) between 10 and 15 then
    return '+' || digits;
  end if;
  if length(digits) between 10 and 15 then
    return '+' || digits;
  end if;
  return null;
end;
$$;

alter table public.org_invites
  add column if not exists phone text,
  add column if not exists first_name text not null default '',
  add column if not exists last_name text not null default '',
  add column if not exists driver_number text,
  add column if not exists access jsonb;

alter table public.org_members
  add column if not exists access jsonb;

alter table public.org_invites
  alter column email drop not null;

update public.org_invites
set email = nullif(lower(btrim(email)), ''),
    phone = public.org_normalize_phone(phone)
where id is not null;

alter table public.org_invites drop constraint if exists org_invites_contact_check;
alter table public.org_invites
  add constraint org_invites_contact_check
  check (
    nullif(btrim(coalesce(email, '')), '') is not null
    or nullif(btrim(coalesce(phone, '')), '') is not null
  );

drop index if exists idx_org_invites_pending_email;
create unique index if not exists idx_org_invites_pending_email
  on public.org_invites (org_id, lower(email))
  where accepted_at is null and email is not null;

drop index if exists idx_org_invites_pending_phone;
create unique index if not exists idx_org_invites_pending_phone
  on public.org_invites (org_id, phone)
  where accepted_at is null and phone is not null;

drop function if exists public.invite_to_org(uuid, text, text);
drop function if exists public.invite_to_org(uuid, text, text, jsonb);

create or replace function public.invite_to_org(
  p_org_id uuid,
  p_email text default null,
  p_role text default 'driver',
  p_access jsonb default null,
  p_phone text default null,
  p_first_name text default '',
  p_last_name text default '',
  p_driver_number text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  me_role text;
  tok uuid;
  r text := lower(trim(p_role));
  em text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  ph text := public.org_normalize_phone(p_phone);
  first_n text := btrim(coalesce(p_first_name, ''));
  last_n text := btrim(coalesce(p_last_name, ''));
  num text := nullif(btrim(coalesce(p_driver_number, '')), '');
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select role into me_role
  from public.org_members
  where org_id = p_org_id and user_id = uid;

  if public.org_role_rank(me_role) < 3 then
    raise exception 'Only the owner or an admin can invite';
  end if;
  if r not in ('admin', 'dispatcher', 'driver') then
    raise exception 'Role must be admin, dispatcher, or driver';
  end if;
  if em is null and ph is null then
    raise exception 'Enter an email or a phone number';
  end if;
  if em is not null and position('@' in em) = 0 then
    raise exception 'Enter a valid email';
  end if;
  if p_phone is not null and btrim(p_phone) <> '' and ph is null then
    raise exception 'Enter a valid phone number';
  end if;
  if char_length(first_n) > 40 or char_length(last_n) > 40 then
    raise exception 'Name is too long';
  end if;
  if char_length(coalesce(num, '')) > 12 then
    raise exception 'Driver number is too long';
  end if;

  insert into public.org_invites (
    org_id, email, phone, role, access, invited_by, first_name, last_name, driver_number
  )
  values (
    p_org_id,
    em,
    ph,
    r,
    public.org_normalize_access(r, p_access),
    uid,
    first_n,
    last_n,
    num
  )
  returning token into tok;

  return tok;
end;
$$;

create or replace function public.accept_org_invite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  em text;
  ph text;
  rec public.org_invites%rowtype;
  v_pay text;
  display text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;

  select lower(coalesce(auth.jwt() ->> 'email', '')) into em;
  select public.org_normalize_phone(auth.jwt() ->> 'phone') into ph;

  select * into rec
  from public.org_invites
  where token = p_token
    and accepted_at is null
    and expires_at > now();

  if rec.id is null then
    raise exception 'Invite not found or expired';
  end if;
  if not (
    (rec.email is not null and em <> '' and lower(rec.email) = em)
    or (rec.phone is not null and ph is not null and rec.phone = ph)
  ) then
    raise exception 'Invite does not match this account';
  end if;
  if exists (select 1 from public.org_members where user_id = uid) then
    raise exception 'Already in a team';
  end if;

  select default_pay_type into v_pay from public.orgs where id = rec.org_id;
  v_pay := coalesce(v_pay, 'contractor');

  insert into public.org_members (org_id, user_id, role, access, pay_type, driver_number)
  values (
    rec.org_id,
    uid,
    rec.role,
    public.org_normalize_access(rec.role, rec.access),
    v_pay,
    rec.driver_number
  );

  display := nullif(btrim(concat_ws(' ', rec.first_name, rec.last_name)), '');

  insert into public.profiles (user_id, nickname, first_name, last_name, phone)
  values (
    uid,
    coalesce(display, ''),
    coalesce(rec.first_name, ''),
    coalesce(rec.last_name, ''),
    coalesce(rec.phone, '')
  )
  on conflict (user_id) do update
  set
    first_name = case when public.profiles.first_name = '' then excluded.first_name else public.profiles.first_name end,
    last_name = case when public.profiles.last_name = '' then excluded.last_name else public.profiles.last_name end,
    phone = case when public.profiles.phone = '' then excluded.phone else public.profiles.phone end,
    nickname = case when public.profiles.nickname = '' then excluded.nickname else public.profiles.nickname end,
    updated_at = now();

  update public.org_invites
  set accepted_at = now()
  where id = rec.id;

  return rec.org_id;
end;
$$;

revoke all on function public.org_normalize_phone(text) from public, anon;
revoke all on function public.invite_to_org(uuid, text, text, jsonb, text, text, text, text) from public, anon;
grant execute on function public.org_normalize_phone(text) to authenticated;
grant execute on function public.invite_to_org(uuid, text, text, jsonb, text, text, text, text) to authenticated;
grant execute on function public.accept_org_invite(uuid) to authenticated;

comment on column public.org_invites.phone is
  'E.164 phone. Invite matches JWT email or phone.';
comment on column public.org_invites.first_name is
  'Copied onto profiles when the person joins.';
