-- Enforce sequential appointment workflow at database level.
create or replace function public.enforce_appointment_flow_transition()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.flow is distinct from old.flow then
    if not (
      (old.flow = 'booked' and new.flow = 'arrived') or
      (old.flow = 'arrived' and new.flow = 'with_doctor') or
      (old.flow = 'with_doctor' and new.flow = 'completed') or
      (old.flow = 'completed' and new.flow = 'converted_to_operation')
    ) then
      raise exception 'Invalid appointment flow transition: % -> %', old.flow, new.flow
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_flow_transition_guard on public.appointments;
create trigger appointments_flow_transition_guard
before update of flow on public.appointments
for each row execute function public.enforce_appointment_flow_transition();
