-- Doctor access: clinical records only, read-only, branch-scoped, and without financial amounts.
ALTER TYPE public.clinic_role ADD VALUE IF NOT EXISTS 'image_manager';
-- Apply after migrations 0001-0013.

-- Doctor's UI module is named patient_files while the patient table gate uses patients.
-- Treat these names as aliases and allow doctors to read operations in their permitted branches.
create or replace function private.has_module_access(org uuid, module_name text)
returns boolean
language sql stable security definer set search_path=''
as $$
 select exists (
  select 1
  from public.profiles p
  where p.id=(select auth.uid())
    and p.organization_id=org
    and p.active
    and (
      p.role='admin'
      or (
        (case p.role::text
          when 'reception' then module_name in ('home','appointments','patients','operations','staff')
          when 'doctor' then module_name in ('home','patients','patient_files','operations')
          when 'image_manager' then module_name in ('home','patients')
          when 'hair_team' then module_name in ('home','patients','operations','staff')
          when 'finance' then module_name in ('home','finance','reports')
          else false
        end)
        and (
          p.permissions->'modules' is null
          or jsonb_typeof(p.permissions->'modules')<>'array'
          or (p.permissions->'modules') ? module_name
          or (module_name='patients' and (p.permissions->'modules') ? 'patient_files')
          or (module_name='patient_files' and (p.permissions->'modules') ? 'patients')
        )
      )
    )
 );
$$;
revoke all on function private.has_module_access(uuid,text) from public, anon;
grant execute on function private.has_module_access(uuid,text) to authenticated;


-- Image Manager needs patient-file module access for image viewing and upload.
-- Doctors do not need the service catalog (it contains prices), so deny its SELECT policy.
drop policy if exists clinic_services_branch_read on public.clinic_services;
create policy clinic_services_branch_read on public.clinic_services for select to authenticated
using (
  organization_id=(select p.organization_id from public.profiles p where p.id=(select auth.uid()) and p.active)
  and (branch_id=(select p.branch_id from public.profiles p where p.id=(select auth.uid()))
       or private.is_admin(organization_id) or private.can_access_branch(organization_id,branch_id))
  and not exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role::text='doctor')
);

drop policy if exists clinic_services_no_doctor_read on public.clinic_services;
create policy clinic_services_no_doctor_read on public.clinic_services as restrictive for all to authenticated
using (not exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text='doctor'))
with check (not exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text='doctor'));

-- Ensure existing doctor accounts have the exact clinical modules used by the app.
update public.profiles
set permissions = jsonb_set(
  coalesce(permissions,'{}'::jsonb),
  '{modules}',
  '["home","patient_files","operations"]'::jsonb,
  true
)
where role::text='doctor';

-- Doctors can read all operations in their assigned branches, not only rows whose
-- free-text implant_doctor_name matches their profile name. The secure view below
-- masks money columns and is the only SELECT surface exposed to authenticated users.
drop policy if exists operations_select on public.operations;
create policy operations_select on public.operations for select to authenticated using (
  private.can_access_branch(organization_id,branch_id)
  and private.has_module_access(organization_id,'operations')
  and exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.organization_id=operations.organization_id
      and p.active and p.role::text in ('admin','reception','hair_team','finance')
  )
);

-- Mask financial columns at the database boundary. The view owner is the migration
-- owner, so branch and module checks are repeated explicitly in the view predicate.
create or replace view public.operations_clinical
with (security_barrier=true, security_invoker=false)
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
    where p.id=(select auth.uid()) and p.active
      and p.role::text in ('admin','reception','finance')
  ) then o.total_amount else null::numeric end as total_amount,
  case when exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.active
      and p.role::text in ('admin','reception','finance')
  ) then o.deposit_amount else null::numeric end as deposit_amount,
  case when exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.active
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
where private.can_access_branch(o.organization_id,o.branch_id)
  and private.has_module_access(o.organization_id,'operations');

-- Remove direct table reads so a doctor cannot bypass the masked view through REST.
revoke select on public.operations from authenticated;
grant select (id) on public.operations to authenticated;
revoke all on public.operations_clinical from public, anon;
grant select on public.operations_clinical to authenticated;

-- Doctors may read clinical visits but cannot create or alter clinical history through this role.
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert to authenticated with check (
  private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception'))
);
drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update to authenticated
using (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception')))
with check (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception')));

-- Patient images: everyone with clinical patient-file access may view; only Admin/Image Manager
-- may upload, replace, or delete image records.
drop policy if exists patient_images_insert on public.patient_images;
create policy patient_images_insert on public.patient_images for insert to authenticated with check (
  private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=patient_images.organization_id
    and p.active and p.role::text in ('admin','image_manager'))
);
drop policy if exists patient_images_update on public.patient_images;
create policy patient_images_update on public.patient_images for update to authenticated
using (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=patient_images.organization_id
    and p.active and p.role::text in ('admin','image_manager')))
with check (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=patient_images.organization_id
    and p.active and p.role::text in ('admin','image_manager')));
drop policy if exists patient_images_delete on public.patient_images;
create policy patient_images_delete on public.patient_images for delete to authenticated using (
  private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=patient_images.organization_id
    and p.active and p.role::text in ('admin','image_manager'))
);

-- Keep the private bucket readable for authorized patient-file users, but restrict all mutations.
drop policy if exists clinic_images_upload on storage.objects;
create policy clinic_images_upload on storage.objects for insert to authenticated with check (
  bucket_id='clinic-patient-images'
  and private.can_access_branch((storage.foldername(name))[1]::uuid,(storage.foldername(name))[2]::uuid)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=(storage.foldername(name))[1]::uuid
    and p.active and p.role::text in ('admin','image_manager'))
);
drop policy if exists clinic_images_update on storage.objects;
create policy clinic_images_update on storage.objects for update to authenticated using (
  bucket_id='clinic-patient-images'
  and private.can_access_branch((storage.foldername(name))[1]::uuid,(storage.foldername(name))[2]::uuid)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=(storage.foldername(name))[1]::uuid
    and p.active and p.role::text in ('admin','image_manager'))
) with check (
  bucket_id='clinic-patient-images'
  and private.can_access_branch((storage.foldername(name))[1]::uuid,(storage.foldername(name))[2]::uuid)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=(storage.foldername(name))[1]::uuid
    and p.active and p.role::text in ('admin','image_manager'))
);
drop policy if exists clinic_images_delete on storage.objects;
create policy clinic_images_delete on storage.objects for delete to authenticated using (
  bucket_id='clinic-patient-images'
  and private.can_access_branch((storage.foldername(name))[1]::uuid,(storage.foldername(name))[2]::uuid)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=(storage.foldername(name))[1]::uuid
    and p.active and p.role::text in ('admin','image_manager'))
);

-- Read-only, doctor-scoped last attended appointment summary. No fees/payment fields are returned.
create or replace function public.doctor_patient_last_appointment(p_patient_id uuid)
returns table(scheduled_at timestamptz, flow text, service_name text, kind text, notes text)
language sql stable security definer set search_path=''
as $$
  select a.scheduled_at, a.flow::text, a.service_name, a.kind::text, a.notes
  from public.appointments a
  join public.patients pt on pt.id=a.patient_id
  join public.profiles me on me.id=(select auth.uid())
  where me.active and me.role::text='doctor'
    and pt.id=p_patient_id
    and pt.organization_id=me.organization_id
    and private.can_access_branch(pt.organization_id,pt.branch_id)
    and a.patient_id=pt.id
    and a.branch_id=pt.branch_id
    and a.flow::text in ('arrived','with_doctor','completed','converted_to_operation')
  order by a.scheduled_at desc
  limit 1;
$$;
revoke all on function public.doctor_patient_last_appointment(uuid) from public, anon;
grant execute on function public.doctor_patient_last_appointment(uuid) to authenticated;

-- Operation lab records are viewable by doctors; mutations remain with Admin/Reception.
drop policy if exists labs_insert on public.operation_labs;
create policy labs_insert on public.operation_labs for insert to authenticated with check (
  private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception'))
);
drop policy if exists labs_update on public.operation_labs;
create policy labs_update on public.operation_labs for update to authenticated
using (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception')))
with check (private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text in ('admin','reception')));
drop policy if exists labs_delete on public.operation_labs;
create policy labs_delete on public.operation_labs for delete to authenticated using (
  private.can_access_branch(organization_id,branch_id)
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active and p.role::text='admin')
);

notify pgrst, 'reload schema';
