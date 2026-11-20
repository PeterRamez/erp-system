-- Keep surgery contact / national ID data outside the broadly branch-readable operations table.
create table if not exists public.operation_private_details(
 operation_id uuid primary key references public.operations(id) on delete cascade,
 organization_id uuid not null references public.organizations(id) on delete cascade,
 branch_id uuid not null references public.branches(id),
 phone text,
 national_id text,
 created_at timestamptz not null default now()
);
insert into public.operation_private_details(operation_id,organization_id,branch_id,phone,national_id)
select id,organization_id,branch_id,phone,national_id from public.operations
on conflict(operation_id) do nothing;
alter table public.operations drop column if exists phone;
alter table public.operations drop column if exists national_id;
alter table public.operation_private_details enable row level security;
create policy operation_private_select on public.operation_private_details for select to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
create policy operation_private_insert on public.operation_private_details for insert to authenticated with check (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
);
create policy operation_private_update on public.operation_private_details for update to authenticated using (
 private.can_access_branch(organization_id,branch_id) and (private.is_admin(organization_id) or exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='reception'))
) with check(private.can_access_branch(organization_id,branch_id));
create policy operation_private_delete on public.operation_private_details for delete to authenticated using(private.is_admin(organization_id));
grant select,insert,update,delete on public.operation_private_details to authenticated;
alter table public.financial_transactions add column if not exists operation_id uuid references public.operations(id) on delete set null;
alter table public.appointments add column if not exists doctor_id uuid references public.profiles(id) on delete set null;
alter table public.financial_transactions add column if not exists appointment_id uuid references public.appointments(id) on delete set null;
