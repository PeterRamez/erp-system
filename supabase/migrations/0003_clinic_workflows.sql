-- Production workflow expansion for Hair Clinic OS. Additive except contact-data hardening.
create table if not exists public.patient_private_details (
  patient_id uuid primary key references public.patients(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  phone text,
  national_id text,
  address text,
  updated_at timestamptz not null default now()
);
insert into public.patient_private_details(patient_id,organization_id,branch_id,phone,national_id,address)
select id,organization_id,branch_id,phone,national_id,address from public.patients
on conflict(patient_id) do update set phone=excluded.phone,national_id=excluded.national_id,address=excluded.address;
-- Contact data is moved to a table with stricter RLS before removing it from the general patient table.
alter table public.patients drop column if exists phone;
alter table public.patients drop column if exists national_id;
alter table public.patients drop column if exists address;

alter table public.patients add column if not exists gender text;
alter table public.operations add column if not exists appointment_id uuid references public.appointments(id) on delete set null;
alter table public.appointments add column if not exists service_name text;
alter table public.appointments add column if not exists service_fee numeric(12,2) not null default 0 check(service_fee>=0);
alter table public.appointments add column if not exists service_payment_mode text check(service_payment_mode in ('paid','operation','manual_price'));
alter table public.appointments add column if not exists arrival_source text;
alter table public.appointments add column if not exists doctor_entered_at timestamptz;
alter table public.appointments add column if not exists converted_to_operation boolean not null default false;
alter table public.appointments add column if not exists age integer check(age between 0 and 125);
alter table public.appointments add column if not exists branch_label text;
alter table public.appointments add column if not exists patient_phone_private text;
update public.appointments set service_name=coalesce(service_name,kind::text), service_fee=coalesce(fee,service_fee,0), service_payment_mode=coalesce(service_payment_mode,service_mode,'paid');
create table if not exists public.appointment_private_details (
 appointment_id uuid primary key references public.appointments(id) on delete cascade,
 phone text,
 created_at timestamptz not null default now()
);
insert into public.appointment_private_details(appointment_id,phone)
select id,phone from public.appointments where phone is not null on conflict(appointment_id) do nothing;
alter table public.appointments drop column if exists phone;

alter table public.visits add column if not exists visit_number text;
alter table public.visits add column if not exists prescription text;

alter table public.operations add column if not exists procedure_type text default 'hair_transplant';
alter table public.operations add column if not exists planned_grafts integer;
alter table public.operations add column if not exists actual_grafts integer;
alter table public.operations add column if not exists status text not null default 'scheduled';
alter table public.operations add column if not exists balance_amount numeric(12,2) generated always as (total_amount-deposit_amount) stored;
alter table public.operation_labs add column if not exists required boolean not null default true;
alter table public.operation_team_assignments add column if not exists team_role text;
-- Team-role compatibility and data normalization.
update public.operation_team_assignments set team_role='extractor' where team_role is null;
alter table public.operation_team_assignments alter column team_role set not null;

alter table public.staff_schedules add column if not exists title text;
create index if not exists staff_schedules_branch_week_idx on public.staff_schedules(organization_id,branch_id,weekday,active);

alter table public.financial_transactions add column if not exists payment_method public.payment_method;
update public.financial_transactions set payment_method='cash' where payment_method is null;
alter table public.financial_transactions alter column payment_method set not null;

alter table public.patient_private_details enable row level security;
create policy patient_private_select on public.patient_private_details for select to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
create policy patient_private_insert on public.patient_private_details for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
create policy patient_private_update on public.patient_private_details for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
) with check (private.can_access_branch(organization_id,branch_id));
create policy patient_private_delete on public.patient_private_details for delete to authenticated using (private.is_admin(organization_id));

alter table public.appointment_private_details enable row level security;
create policy appointment_private_access on public.appointment_private_details for all to authenticated using (
 exists(select 1 from public.appointments a where a.id=appointment_id and (private.is_admin(a.organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception' and p.branch_id=a.branch_id)))
) with check (
 exists(select 1 from public.appointments a where a.id=appointment_id and (private.is_admin(a.organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception' and p.branch_id=a.branch_id)))
);
-- Staff may see the roster for their branch; contact details stay out of the general profile query.
create policy profiles_branch_roster_select on public.profiles for select to authenticated using (
 active and (id=(select auth.uid()) or private.is_admin(organization_id) or branch_id=(select p.branch_id from public.profiles p where p.id=(select auth.uid()) and p.active))
);
grant select,insert,update,delete on public.patient_private_details, public.appointment_private_details to authenticated;
