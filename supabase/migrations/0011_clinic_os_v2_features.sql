-- Clinic OS V2 feature groundwork. Safe additive schema only.
create table if not exists public.clinic_services (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  branch_id uuid not null,
  name text not null,
  kind text not null default 'custom_service',
  fee numeric(12,2) not null default 0 check (fee >= 0),
  active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists clinic_services_org_branch_active_idx on public.clinic_services (organization_id, branch_id, active);
alter table public.clinic_services enable row level security;
drop policy if exists clinic_services_branch_read on public.clinic_services;
create policy clinic_services_branch_read on public.clinic_services for select to authenticated
using (organization_id = (select organization_id from public.profiles where id=(select auth.uid()))
  and (branch_id = (select branch_id from public.profiles where id=(select auth.uid()))
       or private.is_admin(organization_id) or private.can_access_branch(organization_id, branch_id))
;
drop policy if exists clinic_services_admin_manage on public.clinic_services;
create policy clinic_services_admin_manage on public.clinic_services for all to authenticated
using (private.is_admin(organization_id)) with check (private.is_admin(organization_id));
grant select, insert, update, delete on public.clinic_services to authenticated;

alter table public.operations add column if not exists chronic_disease boolean not null default false;
alter table public.operations add column if not exists chronic_disease_details text;
alter table public.operations add column if not exists transplant_team text;
alter table public.operations add column if not exists lab_remarks jsonb not null default '{}'::jsonb;
alter table public.operation_labs add column if not exists remarks text;
alter table public.appointment_private_details add column if not exists address text;
-- Allow staff with branch access to maintain custom service catalog for that branch.
drop policy if exists clinic_services_admin_manage on public.clinic_services;
create policy clinic_services_branch_manage on public.clinic_services for all to authenticated
using (private.can_access_branch(organization_id, branch_id))
with check (private.can_access_branch(organization_id, branch_id));
