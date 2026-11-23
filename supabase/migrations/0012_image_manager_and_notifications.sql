ALTER TYPE public.clinic_role ADD VALUE IF NOT EXISTS 'image_manager';

-- V2 follow-up: image-manager delete permission and finance notifications.
-- Additive migration; review and apply to the intended Supabase project.
drop policy if exists patient_images_delete on public.patient_images;
create policy patient_images_delete on public.patient_images for delete to authenticated
using (private.can_access_branch(organization_id, branch_id) and (
  private.is_admin(organization_id) or exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.organization_id=patient_images.organization_id
      and p.role::text='image_manager' and p.active=true
  )
));

create table if not exists public.finance_notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  branch_id uuid not null,
  transaction_id uuid,
  event_type text not null check(event_type in ('income','expense')),
  message text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  read_by uuid
);
create index if not exists finance_notifications_org_branch_date_idx
  on public.finance_notifications(organization_id, branch_id, created_at desc);
alter table public.finance_notifications enable row level security;
drop policy if exists finance_notifications_branch_read on public.finance_notifications;
create policy finance_notifications_branch_read on public.finance_notifications for select to authenticated
using(private.can_access_branch(organization_id,branch_id));
drop policy if exists finance_notifications_insert on public.finance_notifications;
create policy finance_notifications_insert on public.finance_notifications for insert to authenticated
with check(private.can_access_branch(organization_id,branch_id));
drop policy if exists finance_notifications_admin_update on public.finance_notifications;
create policy finance_notifications_admin_update on public.finance_notifications for update to authenticated
using(private.is_admin(organization_id)) with check(private.is_admin(organization_id));
grant select,insert,update on public.finance_notifications to authenticated;
