# Hair Clinic OS — DHC Hair Experts

Arabic RTL Next.js clinic workflow package. This ZIP includes a workflow-focused frontend and Supabase migration scripts. It is **not yet production-verified** because this environment could not install npm dependencies or connect to a newly approved Supabase project.


## Included features
- Supabase email/password sign-in.
- Branch selector for Admin and branch-scoped data access.
- Appointment creation for registered patients or a new walk-in; a walk-in becomes a patient record only when staff marks `دخل عند الدكتور`.
- Service price rules: كشف 350 EGP, إعادة 200 EGP, ميزوسربي 800 EGP, بلازما 700 EGP; Botox, cold peel, and skin booster are manually priced. Mesotherapy/plasma can be marked as paid or operation/free.
- Appointment arrival / doctor-entry / completed actions and operation conversion.
- Patient files, visit notes, diagnosis, treatment plan, prescription, image timeline, watermarking, and edit flow.
- Hair operation records with total, deposit, balance, national ID and phone in restricted details, graft count, extraction doctor, multi-select opening doctors, implant doctor text, and lab checklist.
- Weekly staff schedules; Friday shown as off in the doctor dashboard.
- Financial transactions by direction and payment method; day/week/month report filters and print.
- Admin user creation endpoint (requires server-only Supabase service-role key).
- RLS migrations move patient contact/address/national ID and operation contact data to restricted tables; doctors are not given access to patient contact fields.

## Setup
1. Create a new Supabase project. Do **not** run these migrations on the previous clinic project unless you intentionally want to migrate it after backup/review.
2. Apply migrations in order: `supabase/migrations/0001_core_schema.sql` through `0005_role_permissions.sql`.
3. In Supabase Auth, create the first administrator login. Create organization and Cairo/Mansoura branches, then create the matching `profiles` record for the admin user. The SQL below is a template; replace the IDs and names with real values:

```sql
insert into public.organizations (name) values ('DHC Hair Experts') returning id;
insert into public.branches (organization_id, name) values
  ('<ORG_UUID>', 'القاهرة'), ('<ORG_UUID>', 'المنصورة') returning id;
insert into public.profiles (id, organization_id, branch_id, full_name, role, active)
values ('<AUTH_USER_UUID>', '<ORG_UUID>', null, '<ADMIN_NAME>', 'admin', true);
```

4. Copy `.env.example` to `.env.local`, then set the new project's URL, publishable/anon key, and server-only `SUPABASE_SERVICE_ROLE_KEY`. Never expose the service-role key in `NEXT_PUBLIC_*` variables.
5. `npm install`, then `npm run dev`.

## User creation endpoint
`POST /api/admin/users` accepts an authenticated admin session and creates an Auth user plus a profile. It requires `SUPABASE_SERVICE_ROLE_KEY` server-side. Inputs: `full_name`, `email`, `password` (minimum 8 chars), `role`, `branch_id`. Roles: admin, reception, doctor, hair_team, finance.


## Migration cautions
- The migration files are intended for a fresh Supabase project, in order. `0003` and later move private contact data to restricted tables and drop those contact columns from general patient and operation tables. Review and back up any existing database before applying them to a populated project.
- SQL migrations have not been executed against a fresh Supabase database in this environment.
- The UI is still an integration build. User-specific custom permission toggles, editable operation team/lab details, automatic clinic branding verification, a dedicated named Dr. Abdelrahman profile workflow, and end-to-end testing remain to be completed. Role-based access and branch separation are also not production-certified until RLS advisors and user-role tests pass.
- Dependency install and `next build` verification could not complete in the tool environment (npm install timed out).

## Unified Calendar Date Picker
All appointment, operation, visit, and finance date/time fields now use the shared visual calendar picker. It supports month navigation, day selection, time selection to the minute, Today, and clearing the date.

## Latest update (November 2026)

- Finance screen includes a clear `Register income / expense` action and daily, weekly, and monthly financial reports with period navigation and print.
- Admin-only user creation remains enforced by the server route. New users can be assigned per-user module permissions within their selected role.
- Operation form now accepts free-text opening doctor names and stores them in `operations.opening_doctor_names`. Migration `0006_opening_doctor_names.sql` adds this column.

## تحديثات التقويم والعمليات

بعد التحديث، نفّذ Migration الجديد من Supabase SQL Editor:
`supabase/migrations/0008_date_based_staff_schedule.sql`

التحديث يضيف تاريخًا محددًا لجداول تواجد الأطباء والفريق مع الاحتفاظ بالتوافر الأسبوعي القديم.
تمت إزالة Dashboard الطبيب وسجل الزيارات من القائمة التشغيلية، وإضافة تقاويم شهرية للمواعيد والعمليات وتواجد الفريق، وخانة البحث عن المرضى، وسعر خدمة قابل للتعديل، وتصنيف الصور الطبية والروشتات، وإمكانية تسجيل دفعات إضافية للعمليات وربطها بالحسابات.


## Update 0009 — Multi-branch access, permissions, and live collaboration

Apply `supabase/migrations/0009_multi_branch_realtime_permissions.sql` after the existing migrations. This update:

- Adds `user_branch_access` so a user may be assigned to Cairo, Mansoura, or both.
- Backfills existing profile primary branches into branch membership records.
- Updates branch-access checks to recognize branch memberships.
- Adds restrictive database module-permission gates so a module hidden in the UI is also blocked by RLS.
- Enables Realtime publication for clinic workflow tables where the `supabase_realtime` publication exists.
- Adds multi-branch selection to user creation and user permissions editing.
- Allows Admin to choose **All branches** and see combined branch records; rows show branch labels in combined views.
- Adds live refresh subscriptions for clinic records so authorized users see updates without manually refreshing.

Users can work simultaneously from separate devices/browser sessions. Supabase Auth session storage is browser-specific; using different accounts in the same browser profile will replace the active account session, so use separate browser profiles/incognito sessions for separate simultaneous logins.

Apply the migration in Supabase SQL Editor or through your established migration workflow before deploying the updated app. Realtime must be enabled in the project for the publication changes to take effect.

## Patient File Structure Upgrade (Nov 22, 2026)

The patient detail modal now has a structured multi-tab patient file:
- Overview with patient summary, visit/appointment/operation/file counts, and admin contact details where the existing role rules allow.
- Clinical history with visit entries including complaint, diagnosis, examination, treatment plan, prescription, and notes.
- Appointment history for the patient.
- Hair operation history with scheduled date, total/deposit/balance, graft estimate, implant doctor, and notes.
- Finance history for Admin and Finance roles only.
- Medical images and prescription image uploads, using the existing private storage and watermark upload flow.

A new visit form writes clinical visit records to the existing `visits` table. This update does not require a new SQL migration.


## Important verification note
The live Demo reference was reviewed at its public routes, but its full client-side internals were not available for code-level extraction. This package adds a production-data patient-file structure based on the existing schema and visible Demo section structure; it is **not certified as a pixel-perfect or feature-for-feature clone of every hidden Demo interaction**. npm dependency installation timed out in the build environment, so a full Next.js build could not be run here. Install dependencies locally and run `npm run build` before deploying.

## Updates in this delivery
- Admin user management now supports listing user email addresses and editing a user's name, email, role, active status, branch access, and resetting their password.
- The staff/doctors navigation entry is removed. Doctor accounts are limited to their own hair-transplant operations by matching their profile name with the operation's implant doctor name.
- Financial transactions support an expense category field and an expense-entry modal with amount, description, category, payment method, and date.

### Required Supabase migration
Before deploying this update, run `supabase/migrations/0010_doctor_dashboard_expense_categories.sql` in the Supabase SQL editor. It adds the expense category column and applies the doctor-specific operations SELECT policy. Keep the `SUPABASE_SERVICE_ROLE_KEY` configured for admin user management endpoints.


## Doctor clinical-only access update

See `README_V2_HANDOFF.md` and migration `supabase/migrations/0014_doctor_clinical_read_only.sql`. Apply migration 0014 after 0013. Doctors are read-only for clinical files, operations, visits, labs, and images; operation amounts are masked in the `operations_clinical` view and direct operation-table SELECT is revoked. Admin/Image Manager retain image mutation rights. Test on staging before production.
