-- 0017: let each doctor see operations where they participate as implant,
-- extractor, or opening doctor. Financial columns remain masked for doctors.
-- Admin and other roles retain their existing branch/module visibility.

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
      select 1
      from public.profiles d
      where d.id = (select auth.uid())
        and d.active
        and d.role::text = 'doctor'
        and (
          -- Implant doctor is stored as a profile name in the existing schema.
          lower(trim(coalesce(o.implant_doctor_name, ''))) =
            lower(trim(coalesce(d.full_name, '')))
          -- Extractor doctor is stored by profile UUID.
          or o.extractor_doctor_id = d.id
          -- Opening doctors can be stored by profile UUIDs.
          or d.id = any(coalesce(o.opening_doctor_ids, '{}'::uuid[]))
          -- Older/current forms also store opening doctor names as free text.
          or exists (
            select 1
            from regexp_split_to_table(
              coalesce(o.opening_doctor_names, ''),
              E'[,،;|/\\n\\r]+'
            ) as opening_name(value)
            where lower(trim(opening_name.value)) = lower(trim(coalesce(d.full_name, '')))
          )
        )
    )
  );

revoke all on public.operations_clinical from public, anon;
grant select on public.operations_clinical to authenticated;
notify pgrst, 'reload schema';
