-- Additive appointment fields. Back up the live database before applying.
alter table public.appointments add column if not exists service_name text;
alter table public.appointments add column if not exists service_fee numeric(12,2) not null default 0 check(service_fee >= 0);
alter table public.appointments add column if not exists service_payment_mode text check(service_payment_mode in ('paid','operation','manual_price'));
alter table public.appointments add column if not exists age integer check(age between 0 and 125);
alter table public.appointments add column if not exists arrival_source text;
alter table public.appointments add column if not exists arrived_at timestamptz;
alter table public.appointments add column if not exists doctor_entered_at timestamptz;
alter table public.appointments add column if not exists converted_to_operation boolean not null default false;
