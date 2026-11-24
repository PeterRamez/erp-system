# Hair Clinic OS – Doctor Dashboards Overlay

## Files changed

- `app/dashboard/page.tsx`
  - Added a doctor-specific dashboard section.
  - Each signed-in doctor sees operations assigned to their profile as implant doctor, extractor doctor, or opening doctor.
  - Added period filters (today, last 7 days, current month, all periods).
  - Added an Admin-only doctor selector; leaving it on “all doctors” shows the organization/branch operations available to Admin, while selecting a doctor filters to that doctor's assignments.
  - Added non-financial metrics and an operation list with a details action.
  - Kept the existing Doctor navigation restrictions and did not add appointments or finance modules.

## New file

- `supabase/migrations/0017_doctor_multi_role_dashboard.sql`
  - Replaces the clinical operations view with an assignment-aware filter.
  - Doctors can read operations where they are assigned as implant doctor, extractor doctor, or opening doctor (UUID or existing free-text name fields).
  - Financial values remain masked for Doctor accounts.
  - Admin and other roles retain their existing visibility conditions.

## Apply

1. Back up the project and database as usual.
2. In Supabase Dashboard, open SQL Editor.
3. Run `supabase/migrations/0017_doctor_multi_role_dashboard.sql` once.
4. Deploy the app changes from this ZIP over the existing project, preserving all other files.
5. Sign in separately with test accounts for each doctor and verify the assigned operation roles.

## Verification status

- ZIP integrity: checked after packaging.
- TypeScript/build/database integration: must be run against the complete project and target Supabase environment before production rollout.
- No live Supabase database was modified by preparing this overlay.
