-- 0016: allow Reception to use the limited finance workspace and receive
-- transaction notifications. Reception can SELECT and INSERT branch-scoped
-- income/expense rows, but cannot UPDATE or DELETE financial transactions.
-- Apply after 0015. This migration is additive and preserves existing data.

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
            when 'reception' then module_name in ('home','appointments','patients','operations','staff','finance')
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

-- Add Finance to Reception's existing module list without removing any
-- previously assigned module. This is the only role permission being expanded.
update public.profiles
set permissions = jsonb_set(
  coalesce(permissions, '{}'::jsonb),
  '{modules}',
  case
    when jsonb_typeof(permissions->'modules') = 'array'
      then case
        when (permissions->'modules') ? 'finance' then permissions->'modules'
        else (permissions->'modules') || '["finance"]'::jsonb
      end
    else '["home","appointments","patients","operations","staff","finance"]'::jsonb
  end,
  true
)
where role::text = 'reception' and active = true;

-- Reception has read-only access to the transaction ledger and can create
-- transactions. Existing UPDATE and DELETE policies remain Admin-only.
drop policy if exists finance_select on public.financial_transactions;
create policy finance_select on public.financial_transactions
for select to authenticated
using (
  private.can_access_branch(organization_id, branch_id)
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.organization_id = financial_transactions.organization_id
      and p.active = true
      and p.role::text in ('admin','finance','reception')
  )
);

drop policy if exists finance_insert on public.financial_transactions;
create policy finance_insert on public.financial_transactions
for insert to authenticated
with check (
  private.can_access_branch(organization_id, branch_id)
  and private.has_module_access(organization_id, 'finance')
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.organization_id = financial_transactions.organization_id
      and p.active = true
      and p.role::text in ('admin','finance','reception')
  )
);

-- Explicitly retain the restrictive module gate. The new function grants
-- Reception only the finance module, not the reports module.
drop policy if exists financial_transactions_module_gate on public.financial_transactions;
create policy financial_transactions_module_gate
as restrictive for all to authenticated
using (
  private.has_module_access(organization_id, 'finance')
  or private.has_module_access(organization_id, 'reports')
)
with check (private.has_module_access(organization_id, 'finance'));

notify pgrst, 'reload schema';

-- Create one notification for every new financial transaction at the database
-- boundary, including appointment fees and operation deposits/payments.
create or replace function public.create_finance_transaction_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), p.email, 'مستخدم')
    into actor_name
  from public.profiles p
  where p.id = new.created_by;

  insert into public.finance_notifications (
    organization_id, branch_id, transaction_id, event_type, message, created_by
  ) values (
    new.organization_id,
    new.branch_id,
    new.id,
    new.direction::text,
    'تم تسجيل ' || case when new.direction::text = 'income' then 'إيراد' else 'مصروف' end ||
      ' بقيمة ' || to_char(new.amount, 'FM999,999,990.00') ||
      ' ج.م: ' || new.description || ' بواسطة ' || coalesce(actor_name, 'مستخدم'),
    new.created_by
  );
  return new;
end;
$$;

revoke all on function public.create_finance_transaction_notification() from public, anon, authenticated;
drop trigger if exists financial_transaction_notification_after_insert on public.financial_transactions;
create trigger financial_transaction_notification_after_insert
after insert on public.financial_transactions
for each row execute function public.create_finance_transaction_notification();
