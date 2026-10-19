-- Customer accounts, courier job lifecycle, and the weekly books packet.
-- 030 and 031 are already on live. Paste this file next.
-- Delivered is the payable status. Existing "done" rows stay valid and still count as delivered.
-- Company take is not stored as its own books document.

create table if not exists public.org_customers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs (id) on delete cascade,
  name text not null,
  billing_email text not null default '',
  phone text not null default '',
  terms text not null default 'Net 30',
  quote_per_mile numeric,
  quote_minimum numeric,
  quote_weekend_mult numeric,
  quote_after_hours_mult numeric,
  company_take_pct numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint org_customers_name_not_blank check (length(btrim(name)) > 0),
  constraint org_customers_quote_per_mile_ok check (quote_per_mile is null or quote_per_mile >= 0),
  constraint org_customers_quote_minimum_ok check (quote_minimum is null or quote_minimum >= 0),
  constraint org_customers_weekend_ok check (
    quote_weekend_mult is null or (quote_weekend_mult >= 1 and quote_weekend_mult <= 5)
  ),
  constraint org_customers_after_hours_ok check (
    quote_after_hours_mult is null or (quote_after_hours_mult >= 1 and quote_after_hours_mult <= 5)
  ),
  constraint org_customers_take_ok check (
    company_take_pct is null or (company_take_pct >= 0 and company_take_pct <= 0.9)
  )
);

create index if not exists idx_org_customers_org_name
  on public.org_customers (org_id, name);

alter table public.org_customers enable row level security;

drop policy if exists "Managers read customers" on public.org_customers;
create policy "Managers read customers"
  on public.org_customers for select
  using ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers insert customers" on public.org_customers;
create policy "Managers insert customers"
  on public.org_customers for insert
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers update customers" on public.org_customers;
create policy "Managers update customers"
  on public.org_customers for update
  using ((select public.is_org_manager_of_org(org_id)))
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers delete customers" on public.org_customers;
create policy "Managers delete customers"
  on public.org_customers for delete
  using ((select public.is_org_manager_of_org(org_id)));

grant select, insert, update, delete on public.org_customers to authenticated;

comment on table public.org_customers is
  'Billing account for a shipper. Null quote columns mean the org rate card.';

alter table public.org_jobs drop constraint if exists org_jobs_status_check;
alter table public.org_jobs
  add constraint org_jobs_status_check
  check (status in ('open', 'picked_up', 'delivered', 'failed', 'cancelled', 'done'));

alter table public.org_jobs
  add column if not exists customer_id uuid references public.org_customers (id) on delete set null,
  add column if not exists failure_reason text not null default '',
  add column if not exists pod_note text not null default '',
  add column if not exists attempt_fee numeric,
  add column if not exists stop_order integer,
  add column if not exists cod_amount numeric,
  add column if not exists cod_collected boolean not null default false;

create index if not exists idx_org_jobs_customer
  on public.org_jobs (customer_id)
  where customer_id is not null;

comment on column public.org_jobs.customer_id is
  'Account that receives the invoice. Delivered jobs without one are held out of the books file.';
comment on column public.org_jobs.attempt_fee is
  'Customer charge when status is failed. Zero means the job is not invoiced.';
comment on column public.org_jobs.cod_amount is
  'Cash collected for the shipper. Not income and not part of the quote.';

create table if not exists public.org_books_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs (id) on delete cascade,
  doc_type text not null check (doc_type in ('invoice', 'bill')),
  doc_number text not null,
  period_start date not null,
  period_end date not null,
  party_key text not null,
  party_name text not null,
  total numeric not null default 0,
  line_count integer not null default 0,
  payload jsonb not null default '[]'::jsonb,
  status text not null default 'ready' check (status in ('ready', 'void')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (org_id, doc_number)
);

create index if not exists idx_org_books_period
  on public.org_books_documents (org_id, period_start, period_end);

alter table public.org_books_documents enable row level security;

drop policy if exists "Managers read books" on public.org_books_documents;
create policy "Managers read books"
  on public.org_books_documents for select
  using ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers insert books" on public.org_books_documents;
create policy "Managers insert books"
  on public.org_books_documents for insert
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers update books" on public.org_books_documents;
create policy "Managers update books"
  on public.org_books_documents for update
  using ((select public.is_org_manager_of_org(org_id)))
  with check ((select public.is_org_manager_of_org(org_id)));

drop policy if exists "Managers delete books" on public.org_books_documents;
create policy "Managers delete books"
  on public.org_books_documents for delete
  using ((select public.is_org_manager_of_org(org_id)));

grant select, insert, update, delete on public.org_books_documents to authenticated;

comment on table public.org_books_documents is
  'Weekly QuickBooks packet. Same doc_number updates in place. Company take is not a document.';

create or replace function public.complete_org_job(p_job_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in';
  end if;
  update public.org_jobs
     set status = 'delivered', updated_at = now()
   where id = p_job_id
     and assigned_user_id = uid
     and status in ('open', 'picked_up');
  if not found then
    raise exception 'Job not found or already closed';
  end if;
end;
$$;

revoke all on function public.complete_org_job(bigint) from public, anon;
grant execute on function public.complete_org_job(bigint) to authenticated;
