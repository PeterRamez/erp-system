# Hair Clinic OS – Service Catalog UI Fix

## Apply
1. Extract this ZIP.
2. Copy the `app` folder into the existing `hair-clinic-production` project root (the folder containing `package.json`).
3. Allow Windows to replace `app/dashboard/page.tsx`.
4. Run `npx tsc --noEmit` and then start the app with `npm run dev`.

## Changes
- Removed the inline name/price inputs from the appointment form's service selector.
- Selecting “＋ إضافة خدمة جديدة” now opens a dedicated page-style form within the dashboard modal.
- Saving creates a row in the existing `clinic_services` table and immediately selects the saved service in the appointment form.
- Existing built-in services and already-saved custom services remain available; no service records are deleted.
- Prevents duplicate service options by normalized name and gives each option a unique React key, addressing the invalid/duplicate key warning in the service dropdown.
- The appointment is not saved when creating a service; the user returns to the appointment form and can then save it normally.

## Validation
- `npx tsc --noEmit`: passed.
- Next.js production build: not completed in this environment because the Linux SWC binary was missing and the environment could not reach npm registry to download it.
- No Supabase migration is required for this UI change; it uses the existing `clinic_services` table and existing insert behavior.
