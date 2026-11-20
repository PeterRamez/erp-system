-- Enforce core module privileges at database level in addition to role-based UI navigation.
-- Admin and reception manage patients/appointments; doctors read patients and write clinical visits.
drop policy if exists patients_insert on public.patients;
create policy patients_insert on public.patients for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
drop policy if exists patients_update on public.patients;
create policy patients_update on public.patients for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
) with check (private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception')));
drop policy if exists appointments_insert on public.appointments;
create policy appointments_insert on public.appointments for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
drop policy if exists appointments_update on public.appointments;
create policy appointments_update on public.appointments for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
) with check (private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception')));
drop policy if exists operations_insert on public.operations;
create policy operations_insert on public.operations for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('reception','hair_team')))
);
drop policy if exists operations_update on public.operations;
create policy operations_update on public.operations for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('reception','hair_team')))
) with check (private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('reception','hair_team')));
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('reception','doctor')))
);
drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('reception','doctor')))
) with check (private.can_access_branch(organization_id,branch_id));
drop policy if exists schedules_insert on public.staff_schedules;
create policy schedules_insert on public.staff_schedules for insert to authenticated with check (private.is_admin(organization_id));
drop policy if exists schedules_update on public.staff_schedules;
create policy schedules_update on public.staff_schedules for update to authenticated using(private.is_admin(organization_id)) with check(private.is_admin(organization_id));
drop policy if exists finance_insert on public.financial_transactions;
create policy finance_insert on public.financial_transactions for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (
  private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='finance')
  or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception' and (appointment_id is not null or operation_id is not null))
 )
);
