-- A job can sit on the board before a driver is chosen.
-- Drivers still only see rows assigned to them.

alter table public.org_jobs
  alter column assigned_user_id drop not null;

comment on column public.org_jobs.assigned_user_id is
  'Driver for this job. Null until the office assigns one.';
