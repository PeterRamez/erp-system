-- 0016: patient date-of-birth support and database-enforced free mesotherapy/plasma.
-- Additive only: no existing patient or financial rows are deleted or rewritten.

alter table public.patients
  add column if not exists date_of_birth date;

alter table public.appointment_private_details
  add column if not exists national_id text,
  add column if not exists date_of_birth date,
  add column if not exists gender text;

alter table public.appointments
  drop constraint if exists appointments_service_mode_check;
alter table public.appointments
  drop constraint if exists appointments_service_payment_mode_check;
alter table public.appointments
  add constraint appointments_service_mode_check
  check (service_mode is null or service_mode in ('paid','free','operation','manual_price'));
alter table public.appointments
  add constraint appointments_service_payment_mode_check
  check (service_payment_mode is null or service_payment_mode in ('paid','free','operation','manual_price'));

create or replace function private.enforce_free_mesotherapy_plasma()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  effective_mode text;
  catalog_price numeric(12,2);
begin
  effective_mode := coalesce(new.service_payment_mode, new.service_mode, 'paid');
  if new.kind::text in ('mesotherapy','plasma') then
    if coalesce(new.service_payment_mode,'') in ('free','operation')
      or coalesce(new.service_mode,'') in ('free','operation') then
      new.fee := 0;
      new.service_fee := 0;
    elsif tg_op = 'UPDATE'
      and (coalesce(old.service_payment_mode,'') in ('free','operation')
        or coalesce(old.service_mode,'') in ('free','operation'))
      and coalesce(new.service_payment_mode,'paid') not in ('free','operation')
      and coalesce(new.service_mode,'paid') not in ('free','operation') then
      select cs.fee into catalog_price from public.clinic_services cs
      where cs.organization_id = new.organization_id and cs.branch_id = new.branch_id
        and cs.kind = new.kind::text and cs.active = true
      order by cs.created_at desc limit 1;
      if catalog_price is null then
        catalog_price := case new.kind::text when 'mesotherapy' then 800 when 'plasma' then 700 else 0 end;
      end if;
      new.fee := catalog_price;
      new.service_fee := catalog_price;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_free_mesotherapy_plasma() from public, anon, authenticated;
drop trigger if exists appointments_enforce_free_service on public.appointments;
create trigger appointments_enforce_free_service
before insert or update of kind, service_mode, service_payment_mode, fee, service_fee
on public.appointments for each row execute function private.enforce_free_mesotherapy_plasma();

create or replace function private.sync_patient_age_from_birth_date()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.date_of_birth is not null then
    new.age := extract(year from age(current_date, new.date_of_birth))::integer;
    if new.age < 0 or new.age > 125 then
      raise exception 'تاريخ الميلاد خارج النطاق المسموح به';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.sync_patient_age_from_birth_date() from public, anon, authenticated;
drop trigger if exists patients_sync_age_from_birth_date on public.patients;
create trigger patients_sync_age_from_birth_date
before insert or update of date_of_birth on public.patients
for each row execute function private.sync_patient_age_from_birth_date();
