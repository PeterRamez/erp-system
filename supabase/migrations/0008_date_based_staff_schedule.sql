-- Date-based staff availability; existing weekly schedules remain supported.
ALTER TABLE public.staff_schedules ADD COLUMN IF NOT EXISTS schedule_date date;
CREATE INDEX IF NOT EXISTS staff_schedules_branch_date_idx ON public.staff_schedules(branch_id, schedule_date) WHERE schedule_date IS NOT NULL;
