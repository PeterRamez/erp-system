# Clinic OS V2 – Updated change ledger

## Existing project preserved
The original project structure, source modules, migrations, brand assets, and configuration are retained. Changes are additive where database work is involved.

## Implemented in this update
- Added `image_manager` role to role options and module defaults; image-management actions are exposed only to Admin/Image Manager in the UI.
- Doctor/image-viewer flow is read-only for image uploads and deletes; images are shown in the patient file and open in a full-size preview link.
- Removed the prescription category selector from the image upload UI; image area is labeled as patient images.
- Added a free service-mode choice for the special service selector, with its appointment fee normalized to zero.
- Financial entry creates a finance notification record when the new notifications table is present.
- Added migration `0012_image_manager_and_notifications.sql` for Image Manager deletion policy and finance-notification table.
- Existing migration `0011_clinic_os_v2_features.sql` and its custom service, chronic-condition, team, lab-remarks, and appointment-address groundwork are preserved.

## Requested scope still incomplete / requires follow-up implementation and testing
- Dedicated doctor-facing `Patient Files` screen with reduced fields and separate navigation from `Customer List`.
- Strict server/database isolation for doctor access to administrative, private and financial data (including RLS verification and API paths).
- Operation-details comprehensive patient display, operation editing, and doctor-specific operation dashboards/filtering.
- Reception limited finance UI, permissions and transaction-notification review workflow.
- Appointment/calender paid-total footer, complete validation of all required fields, and tested linked-finance cancellation semantics.
- Mesotherapy paid-to-free workflow verified against prior ledger entries and edit scenarios (not merely new appointment selection).
- Image manager and doctor roles need end-to-end storage/RLS audit, including Supabase Storage bucket policies.
- Operation and patient modal layout/labels cleanup, removing requested exam/prescription/details controls and visit-count label cleanup.

## Migrations
Apply migrations 0011 and 0012 in Supabase after review. They have not been applied to any live database by this package. Existing data is not intentionally removed.

## Build verification
Run `npm install` and `npm run build` before deployment. A build was not verified in this update environment unless indicated in the handoff report.

## Additional follow-up edits (2026-11-23)
- Added a separate `Patient Files` navigation destination for Doctor role; its patient list is reduced and doctor-specific (no patient deletion controls or finance module).
- Doctor-facing patient record controls suppress administrative/private details, finance and appointment tabs, and doctor-only clinical controls; clinical record cards no longer display examination or prescription fields.
- Reception is assigned the finance module in default role navigation; the finance screen suppresses net-result summary for Reception and exposes a limited-recording banner.
- Appointment creation validates scheduled date/time and requires contact phone/address for new patient records.
- Appointment calendar now shows daily/monthly appointment-fee sums.
- Patient images are arranged vertically; doctor access remains preview-only in the UI while Admin/Image Manager controls remain.
- Added migration `0013_v2_reception_notifications_and_service_catalog.sql` for reception-linked financial-entry policy changes.

## Validation status / remaining risks
- TypeScript/build checks could not be validated because dependencies (`next`, `react`, Supabase packages) were not installed; install timed out and `tsc` output is dominated by missing dependency/type errors.
- This pass is still not a full implementation of the original request. Specifically, comprehensive operation editing, complete doctor-specific dashboard filters, audited server-side Doctor patient/operation scope, a true restricted Reception finance view, notifications review/acknowledgement UI, and verified paid-to-free reconciliation for previously recorded transactions remain incomplete.
- Database migrations must be reviewed and applied in a test Supabase environment; role/module policies and storage policies need verification before production use.
