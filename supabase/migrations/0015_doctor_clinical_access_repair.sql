-- 0015: repair doctor clinical access and keep appointments Reception-only.
-- Apply after migrations 0001-0013; it is also safe after a partial/complete 0014 run.

ALTER TYPE public.clinic_role ADD VALUE IF NOT EXISTS 'image_manager';

-- Keep each doctor's role modules aligned with the clinical-only UI.
update public.profiles
set permissions = jsonb_set(
  coalesce(permissions, '{}'::jsonb),
  '{modules}',
  '["home","patient_files","operations"]'::jsonb,
  true
)
where role::text = 'doctor' and active = true;

-- Ensure a profile's primary branch is represented in its branch-access rows.
insert into public.user_branch_access (user_id, organization_id, branch_id)
select p.id, p.organization_id, p.branch_id
from public.profiles p
where p.active = true and p.role::text = 'doctor' and p.branch_id is not null
on conflict (user_id, branch_id) do update
set organization_id = excluded.organization_id;

-- Explicit, stable module alias: the UI calls the section patient_files,
-- while the underlying patient table's RLS gate calls it patients.
create or replace function private.has_module_access(org uuid, module_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.organization_id = org
      and p.active = true
      and (
        p.role::text = 'admin'
        or (
          case p.role::text
            when 'reception' then module_name in ('home','appointments','patients','operations','staff')
            when 'doctor' then module_name in ('home','patients','patient_files','operations')
            when 'hair_team' then module_name in ('home','patients','operations','staff')
            when 'image_manager' then module_name in ('home','patients','patient_files')
            when 'finance' then module_name in ('home','finance','reports')
            else false
          end
          and (
            p.permissions->'modules' is null
            or jsonb_typeof(p.permissions->'modules') <> 'array'
            or (p.permissions->'modules') ? module_name
            or (module_name = 'patients' and (p.permissions->'modules') ? 'patient_files')
            or (module_name = 'patient_files' and (p.permissions->'modules') ? 'patients')
          )
        )
      )
  );
$$;

revoke all on function private.has_module_access(uuid,text) from public, anon;
grant execute on function private.has_module_access(uuid,text) to authenticated;

-- Restore/ensure branch-scoped patient reads for roles that have the patient module.
drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients
for select to authenticated
using (
  private.can_access_branch(organization_id, branch_id)
  and private.has_module_access(organization_id, 'patients')
);

-- The restrictive gate remains in place for writes too, but uses the alias-aware function.
drop policy if exists patients_module_gate on public.patients;
create policy patients_module_gate on public.patients
as restrictive for all to authenticated
using (private.has_module_access(organization_id, 'patients'))
with check (private.has_module_access(organization_id, 'patients'));

-- Doctors may read operation records only when assigned as the implant doctor,
-- and only within their assigned branches. Financial columns are masked.
create or replace view public.operations_clinical
with (security_barrier = true, security_invoker = false)
as
select
  o.id,
  o.organization_id,
  o.branch_id,
  o.patient_id,
  o.appointment_id,
  o.scheduled_at,
  case when exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.active
      and p.role::text in ('admin','reception','finance')
  ) then o.total_amount else null::numeric end as total_amount,
  case when exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.active
      and p.role::text in ('admin','reception','finance')
  ) then o.deposit_amount else null::numeric end as deposit_amount,
  case when exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.active
      and p.role::text in ('admin','reception','finance')
  ) then o.balance_amount else null::numeric end as balance_amount,
  o.extractor_doctor_id,
  o.opening_doctor_ids,
  o.opening_doctor_names,
  o.implant_doctor_name,
  o.notes,
  o.created_by,
  o.created_at,
  o.updated_at,
  o.procedure_type,
  o.planned_grafts,
  o.actual_grafts,
  o.status,
  o.chronic_disease,
  o.chronic_disease_details,
  o.transplant_team,
  o.lab_remarks
from public.operations o
where private.can_access_branch(o.organization_id, o.branch_id)
  and private.has_module_access(o.organization_id, 'operations')
  and (
    not exists (
      select 1 from public.profiles d
      where d.id = (select auth.uid())
        and d.active
        and d.role::text = 'doctor'
    )
    or exists (
      select 1 from public.profiles d
      where d.id = (select auth.uid())
        and d.active
        and d.role::text = 'doctor'
        and lower(trim(coalesce(o.implant_doctor_name,''))) =
            lower(trim(coalesce(d.full_name,'')))
    )
  );

revoke all on public.operations_clinical from public, anon;
grant select on public.operations_clinical to authenticated;

-- Appointments and booking are Reception-only. Doctors cannot query appointment rows.
drop policy if exists appointments_doctor_block on public.appointments;
create policy appointments_doctor_block on public.appointments
as restrictive for all to authenticated
using (
  not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.active and p.role::text = 'doctor'
  )
)
with check (
  not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.active and p.role::text = 'doctor'
  )
);

-- Doctors do not receive appointment data through the legacy summary RPC either.
do $$
begin
  if to_regprocedure('public.doctor_patient_last_appointment(uuid)') is not null then
    execute 'revoke execute on function public.doctor_patient_last_appointment(uuid) from public, anon, authenticated';
  end if;
end $$;

-- Explicit grants and schema refresh for PostgREST.
grant select on public.patients, public.visits, public.patient_images, public.operation_labs to authenticated;
notify pgrst, 'reload schema';
