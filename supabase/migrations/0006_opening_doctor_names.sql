-- Allow staff to enter opening doctors as free text (not only select existing users).
alter table public.operations add column if not exists opening_doctor_names text;
