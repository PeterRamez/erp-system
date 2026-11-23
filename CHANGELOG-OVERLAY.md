# Hair Clinic OS – Overlay Patch (2026-11-23)

This archive is an overlay patch for the existing `hair-clinic-production` project. It is not a replacement project.

## Files included

### Updated
- `app/dashboard/page.tsx`
- `app/page.tsx`

### Added
- `supabase/migrations/0016_reception_limited_finance_and_operation_details.sql`

## Changes

1. Removed the examination and prescription fields from the visit-entry form and their display in the patient medical-visit history. Existing database columns and historical values are intentionally retained; no patient/visit data is deleted.
2. Expanded operation details to load and show the linked patient's available profile information. Private contact fields (phone, national ID, address) are requested and displayed only for Admin and Reception, following the existing `patient_private_details` RLS policy. Doctor and Finance views do not request those private fields.
3. Added an operation-edit form for Admin and Reception. It updates operation scheduling, procedure, total, graft counts, assigned doctors, chronic-condition details, transplant team, lab remarks and notes. The already-paid deposit is read-only; total cannot be reduced below the amount already paid.
4. Added a limited Reception finance workspace: branch-scoped viewing and recording of income/expenses, with no Reception edit/delete controls, no Reports module, and no net-balance metric. The SQL migration adds `finance` to Reception's existing module list without removing other modules.
5. Added a database trigger that creates a `finance_notifications` row for every newly inserted financial transaction, including appointment fees, operation deposits, later payments, and manually entered income/expenses. The Finance screen displays the latest notices.
6. Kept RLS enabled and added only additive policy/function/trigger changes. No existing data table is dropped, truncated, or recreated.

## Installation

1. Make a backup of the current project.
2. Extract this ZIP directly into the existing project root — the folder that contains `package.json`.
3. Allow the two `app` page files to be replaced.
4. In the Supabase SQL Editor, run the new file:
   `supabase/migrations/0016_reception_limited_finance_and_operation_details.sql`
5. Wait for the migration to complete successfully, then redeploy the project.

Do not run the SQL before confirming that migrations `0001` through `0015` have already been applied to the same Supabase project.

## Verification performed

- TypeScript: `node node_modules/typescript/bin/tsc --noEmit --pretty false` — passed.
- Next.js Build: attempted, but blocked because the environment tried to download `@next/swc-linux-x64-gnu` and DNS/network access to `registry.npmjs.org` was unavailable. Build success is therefore not claimed.
- Lint: the project has no `lint` script in `package.json`; not run.
- Supabase migration execution and role/RLS runtime tests: not run because no live Supabase connection was available.

## Notes

- Old examination/prescription data remains in the database but is no longer shown or entered in the visit UI.
- The notification scope implemented here is every financial transaction. It is not a general notification feed for unrelated non-financial application actions.
- Reception can add and view transactions within its authorized branch, but cannot edit/delete them or access Finance Reports.
