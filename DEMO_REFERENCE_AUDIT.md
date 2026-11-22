# Demo Reference Audit — Hair Clinic OS

Reference: https://clinic-coral-kappa.vercel.app/

## Verified visible sections (public demo routes)
- Dashboard (`/`): clinic overview, operational summary for Cairo and Mansoura, patients/operations/today's appointments/collections metrics, upcoming operations, shortcuts.
- Patient files (`/patients`): search by name/code/phone, create patient, patient file summary, clinical data/images/documents (the public page describes this scope).
- Hair transplant operations (`/operations`): monthly calendar, date selection, selected-day bookings, branch counts (Cairo/Mansoura), month list/search, create operation. Demo copy states an 8-operation-per-day clinic-wide limit.
- Appointments (`/appointments`): monthly calendar, day selection, create appointment, patient/doctor search, appointment list.
- Doctors/team (`/doctors`): team list/search and adding a team member; specialty, branch, phone, status.
- Finance (`/finance`): payment registration, collection metrics, payments search/list, patient/description/amount/payment method details.

## Existing project modules preserved
The project already includes the above major modules plus user administration/permissions and reports. Its patient file has clinical visits, appointment/operation/finance history, images and prescription uploads; appointment workflow; operation financial details and labs; staff schedules; multi-branch access; Supabase Auth/RLS/Realtime.

## Changes in this reference pass
- Reordered primary navigation to follow the demo's six-section sequence while retaining the project's extra Users/Permissions and Reports sections.
- Added Dashboard quick shortcuts for patient files, operation bookings, appointments, and finance; they navigate to the existing modules and do not replace or remove any existing functionality.

## Differences / limits that still require a full browser interaction audit
- The demo's stated daily maximum of 8 operations across branches is visible in the public page, but enforcement is not verified from the static route extraction; this package does not add enforcement without confirming the database-safe cross-branch logic.
- Modal field details, edit/delete behavior, patient-file tabs, image upload mechanics, role restrictions, and edge-case workflows cannot be exhaustively verified from the public page extraction.
- Demo is a browser-local editable evaluation mode. The project remains Supabase-backed and preserves its authentication, database, branch access, permissions, and Realtime architecture.

## Verification
- Public routes and visible labels were checked using the deployed demo pages.
- `npm install` timed out in the available environment, so `next build` could not be run here. Please run `npm install` and `npm run build` in a network-enabled environment before deployment.
