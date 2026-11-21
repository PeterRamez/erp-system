-- Multi-branch user access, strict module permission checks, and realtime change feed.
create table if not exists public.user_branch_access (
  user_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, branch_id)
);
create index if not exists user_branch_access_org_branch_idx on public.user_branch_access(organization_id, branch_id);
insert into public.user_branch_access(user_id,organization_id,branch_id)
select p.id,p.organization_id,p.branch_id from public.profiles p where p.branch_id is not null
on conflict(user_id,branch_id) do nothing;

create or replace function private.can_access_branch(org uuid, br uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
   select 1 from public.profiles p
   where p.id=(select auth.uid()) and p.organization_id=org and p.active
   and (p.role='admin' or exists(
      select 1 from public.user_branch_access uba
      where uba.user_id=p.id and uba.organization_id=org and uba.branch_id=br
   ) or p.branch_id=br)
 );
$$;
create or replace function private.has_module_access(org uuid, module_name text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.profiles p
  where p.id=(select auth.uid()) and p.organization_id=org and p.active
  and (
    p.role='admin' or (
      (case p.role
        when 'reception' then module_name in ('home','appointments','patients','operations','staff')
        when 'doctor' then module_name in ('home','patients')
        when 'hair_team' then module_name in ('home','patients','operations','staff')
        when 'finance' then module_name in ('home','finance','reports')
        else false end)
      and (p.permissions->'modules' is null or jsonb_typeof(p.permissions->'modules')<>'array' or (p.permissions->'modules') ? module_name)
    )
  )
 );
$$;
revoke all on function private.can_access_branch(uuid,uuid) from public, anon;
revoke all on function private.has_module_access(uuid,text) from public, anon;
grant execute on function private.can_access_branch(uuid,uuid) to authenticated;
grant execute on function private.has_module_access(uuid,text) to authenticated;

alter table public.user_branch_access enable row level security;
drop policy if exists user_branch_access_read on public.user_branch_access;
create policy user_branch_access_read on public.user_branch_access for select to authenticated using (
 user_id=(select auth.uid()) or private.is_admin(organization_id) or private.can_access_branch(organization_id,branch_id)
);
drop policy if exists user_branch_access_admin_manage on public.user_branch_access;
create policy user_branch_access_admin_manage on public.user_branch_access for all to authenticated using(private.is_admin(organization_id)) with check(private.is_admin(organization_id));

-- Restrictive module gates. Existing role and branch policies remain in place and continue
-- to enforce role-specific operations; these gates additionally enforce the saved module list.
drop policy if exists patients_module_gate on public.patients;
create policy patients_module_gate on public.patients as restrictive for all to authenticated using(private.has_module_access(organization_id,'patients')) with check(private.has_module_access(organization_id,'patients'));
drop policy if exists appointments_module_gate on public.appointments;
create policy appointments_module_gate on public.appointments as restrictive for all to authenticated using(private.has_module_access(organization_id,'appointments')) with check(private.has_module_access(organization_id,'appointments'));
drop policy if exists operations_module_gate on public.operations;
create policy operations_module_gate on public.operations as restrictive for all to authenticated using(private.has_module_access(organization_id,'operations')) with check(private.has_module_access(organization_id,'operations'));
drop policy if exists visits_module_gate on public.visits;
create policy visits_module_gate on public.visits as restrictive for all to authenticated using(private.has_module_access(organization_id,'patients')) with check(private.has_module_access(organization_id,'patients'));
drop policy if exists patient_images_module_gate on public.patient_images;
create policy patient_images_module_gate on public.patient_images as restrictive for all to authenticated using(private.has_module_access(organization_id,'patients')) with check(private.has_module_access(organization_id,'patients'));
drop policy if exists patient_private_details_module_gate on public.patient_private_details;
create policy patient_private_details_module_gate on public.patient_private_details as restrictive for all to authenticated using(private.has_module_access(organization_id,'patients')) with check(private.has_module_access(organization_id,'patients'));
drop policy if exists operation_private_details_module_gate on public.operation_private_details;
create policy operation_private_details_module_gate on public.operation_private_details as restrictive for all to authenticated using(private.has_module_access(organization_id,'operations')) with check(private.has_module_access(organization_id,'operations'));
drop policy if exists operation_labs_module_gate on public.operation_labs;
create policy operation_labs_module_gate on public.operation_labs as restrictive for all to authenticated using(private.has_module_access(organization_id,'operations')) with check(private.has_module_access(organization_id,'operations'));
drop policy if exists operation_team_assignments_module_gate on public.operation_team_assignments;
create policy operation_team_assignments_module_gate on public.operation_team_assignments as restrictive for all to authenticated using(private.has_module_access(organization_id,'operations')) with check(private.has_module_access(organization_id,'operations'));
drop policy if exists staff_schedules_module_gate on public.staff_schedules;
create policy staff_schedules_module_gate on public.staff_schedules as restrictive for all to authenticated using(private.has_module_access(organization_id,'staff')) with check(private.has_module_access(organization_id,'staff'));
drop policy if exists financial_transactions_module_gate on public.financial_transactions;
create policy financial_transactions_module_gate on public.financial_transactions as restrictive for all to authenticated using(private.has_module_access(organization_id,'finance') or private.has_module_access(organization_id,'reports')) with check(private.has_module_access(organization_id,'finance'));

-- Supabase Realtime publication. Duplicate table membership is ignored safely.
do $$
declare t text;
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  foreach t in array['patients','appointments','operations','financial_transactions','profiles','user_branch_access','staff_schedules','visits','patient_images','operation_labs','appointment_private_details','patient_private_details','operation_team_assignments','operation_private_details'] loop
   if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
    execute format('alter publication supabase_realtime add table public.%I',t);
   end if;
  end loop;
 end if;
end $$;

grant select,insert,update,delete on public.user_branch_access to authenticated;
drop policy if exists profiles_branch_roster_select on public.profiles;
create policy profiles_branch_roster_select on public.profiles for select to authenticated using (
 active and (id=(select auth.uid()) or private.is_admin(organization_id) or private.can_access_branch(organization_id,branch_id) or exists(select 1 from public.user_branch_access uba where uba.user_id=id and uba.organization_id=organization_id and private.can_access_branch(uba.organization_id,uba.branch_id)))
);
drop policy if exists appointment_private_details_module_gate on public.appointment_private_details;
create policy appointment_private_details_module_gate on public.appointment_private_details as restrictive for all to authenticated using (
 private.has_module_access((select a.organization_id from public.appointments a where a.id=appointment_id),'appointments')
) with check (
 private.has_module_access((select a.organization_id from public.appointments a where a.id=appointment_id),'appointments')
);
-- Patient image objects are also protected by the patients module permission.
drop policy if exists clinic_images_module_gate on storage.objects;
create policy clinic_images_module_gate on storage.objects as restrictive for all to authenticated using (
 bucket_id<>'clinic-patient-images' or private.has_module_access((storage.foldername(name))[1]::uuid,'patients')
) with check (
 bucket_id<>'clinic-patient-images' or private.has_module_access((storage.foldername(name))[1]::uuid,'patients')
);
