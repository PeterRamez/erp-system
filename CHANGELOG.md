# CHANGELOG — Hair Clinic OS

## Unreleased — patient auto-fill and free mesotherapy/plasma

### Modified files

- `app/page.tsx`
  - Added a shared patient-ID selection flow for the existing appointment and operation patient pickers.
  - On selection, loads the selected patient record and permitted contact details; clears old patient values when the selection changes or is cleared.
  - Uses the original `patient_id`; does not create another patient for an already selected record. New-patient flows check normalized names and (for Reception/Admin) normalized phone numbers before creating a record.
  - Loads the full patient record when converting a completed appointment to an operation.
  - Adds date-of-birth and gender fields to the relevant patient/appointment/operation forms and derives age from date of birth.
  - Makes the mesotherapy/plasma free choice set the fee to zero and disables manual price editing while free; switching back to paid restores the configured catalog price or the existing standard price.
  - Saves edited demographic/contact details to the original patient record for Reception/Admin only, subject to existing Supabase RLS.
  - When converting an unlinked legacy appointment, checks for a matching patient by normalized name and then by phone before creating a patient; preserves existing contact values when merging appointment details.
- `app/dashboard/page.tsx`
  - Applies the same changes as the root dashboard entry point. The two dashboard files remain identical.
- `supabase/migrations/0016_patient_autofill_and_free_services.sql` (new)
  - Adds `patients.date_of_birth` and temporary demographic fields to `appointment_private_details` using additive `ADD COLUMN IF NOT EXISTS` statements.
  - Allows the existing service-mode fields to store `free` without changing earlier migrations.
  - Adds a database trigger that forces both `appointments.fee` and `appointments.service_fee` to zero for free/operation mesotherapy and plasma, regardless of a client-supplied price.
  - When a free mesotherapy/plasma appointment is changed back to paid, restores the latest matching active catalog fee or the existing standard fallback (mesotherapy 800, plasma 700).
  - Adds a database trigger to derive patient age from date of birth and reject out-of-range dates.
- `lib/patient-autofill.ts` (new)
  - Centralizes lookup by patient ID and age calculation.
  - Fetches phone, national ID, and address only for Reception/Admin; it does not request private contact details for Doctor or other roles.
- `CHANGELOG.md` (new)
  - Documents modified/new files and migration instructions.

### Supabase migration instructions

**Do not edit or rerun old migrations.** This is a new additive migration numbered `0016`.

Option A — Supabase Dashboard:
1. Open the correct Supabase project.
2. Open **SQL Editor** and create a new query.
3. Copy the complete contents of `supabase/migrations/0016_patient_autofill_and_free_services.sql` into the editor.
4. Review the SQL, then run it once against the intended project.
5. Confirm that the migration completed successfully before deploying the application code.

Option B — Supabase CLI (if this repository is linked to the intended project):
1. Back up the database first.
2. Confirm the CLI is linked to the correct Supabase project.
3. Run `supabase db push` from the project directory.
4. Review the migration output and verify migration `0016` is recorded as applied.

The migration does not contain `DROP TABLE`, `TRUNCATE`, or destructive data-copy operations. It only replaces the two appointment service-mode check constraints and adds columns/functions/triggers. Existing records are retained.

### Validation performed

- `npx tsc --noEmit` — **passed** after the changes.
- Baseline TypeScript errors in the original project were also checked before finalizing; small type-only fixes were applied to remove those existing errors without changing runtime behavior.
- `npm run lint` — not available; the supplied `package.json` has no lint script.
- `npm run build` — **not completed**. The archived `node_modules/.bin/next` lacks executable permission in this environment; invoking Next directly then required downloading the Linux SWC binary, but network access to the npm registry was unavailable (`EAI_AGAIN`).
- Live Supabase migration execution and end-to-end role/data tests — **not run** because no connected test database/session is available in this workspace.

### Scope notes

- The supplied application currently has patient selectors in the appointment and operation forms; these are the existing pickers wired to the shared helper.
- The supplied UI does not contain an appointment-edit form/action. No new appointment editing workflow was invented as part of this patch; if one is added later, it should call `fetchPatientFormData` on patient selection as well.
- Existing Doctor permissions and the existing Doctor clinical-only RLS migrations were not broadened. The new lookup does not request private contact fields for Doctor.
