-- Doctor-specific operation access and expense categories.
alter table public.financial_transactions add column if not exists expense_category text;

-- Replace the broad operation read policy with a doctor-scoped policy while keeping
-- normal branch access for administrative/operations roles.
drop policy if exists operations_select on public.operations;
create policy operations_select on public.operations for select to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (
  private.is_admin(organization_id) or exists(
   select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=operations.organization_id and p.active and p.role in ('reception','hair_team','finance')
  ) or exists(
   select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=operations.organization_id and p.active and p.role='doctor' and p.full_name=operations.implant_doctor_name
  )
);
-- Existing doctor profiles get the operations module.
update public.profiles set permissions=coalesce(permissions,'{}'::jsonb) || jsonb_build_object('modules', jsonb_build_array('home','operations')) where role='doctor';
