# Hair Clinic OS V2 handoff — update pass

This package preserves the original project and adds an incremental follow-up pass.

Implemented in the code pass:
- Doctor-specific `Patient Files` navigation and a reduced patient listing.
- Doctor view hides patient administrative/private details, financial and appointment tabs, and editing controls for visits/images.
- Reception role default navigation includes limited finance module; net total summary suppressed for reception.
- Appointment save validation checks date/time and contact phone/address for new patients.
- Calendar shows sums of appointment fees for selected day and month.
- Patient-image layout is vertical.
- New SQL migration `0013_v2_reception_notifications_and_service_catalog.sql`.

## Caution
This remains an incremental implementation. Reception restrictions, notification review UI, transaction reconciliation for Paid-to-Free conversions, and a complete security audit still require work. UI restrictions alone are not security controls. Do not deploy to real patient data until migrations/RLS/Storage policies are audited and a full build/test run succeeds.

Build validation was not completed: dependency installation timed out and TypeScript reports missing Next/React/Supabase dependencies.


## Doctor clinical-only permissions — migration 0014

This update adds `supabase/migrations/0014_doctor_clinical_read_only.sql` and updates the dashboard:
- Doctor accounts get `home`, `patient_files`, and `operations` modules; patient-files module naming is mapped to the database `patients` gate.
- Doctors can read patient records, visits, images, operation details, and operation lab records only in their assigned branches.
- The last attended appointment is returned through `doctor_patient_last_appointment`, which returns no fees or payment fields.
- Operation reads use `public.operations_clinical`; monetary columns are masked for doctors, and direct SELECT on `public.operations` is revoked (only `id` remains selectable for insert/delete return values).
- Doctors cannot access financial transactions, appointment fee records, or the clinic service catalog.
- Doctor role is read-only for visits, operation labs, operation records, and images. Image upload/update/delete is restricted to Admin or Image Manager in both the image table and Storage policies.
- The doctor UI hides financial totals, payment columns, upload/delete controls, and operation creation controls; it displays visit examination/prescription, operation clinical details, labs, images, and last attended appointment.

### Apply the database migration

Run migrations `0001` through `0013` first if they are not already applied, then run `0014_doctor_clinical_read_only.sql` in the Supabase SQL Editor. The application code expects the `operations_clinical` view and `doctor_patient_last_appointment` RPC to exist.

### Validation note

The archive did not include `node_modules` or a lockfile. A TypeScript check was attempted, but it cannot complete because Next.js, React, and Supabase dependencies are not installed in this working copy. No live Supabase project was connected, so the SQL migration has not been executed against production data. Apply it to a staging project and test each role before production use.
