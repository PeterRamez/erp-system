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

## حذف السجلات نهائيًا (Admin)
- أضيفت أزرار **حذف** في المواعيد، ملفات المرضى، العمليات، الزيارات، جداول الفريق، الحركات المالية، صور المرضى، والمستخدمين.
- أزرار الحذف تظهر للـ Admin فقط، مع تأكيد قبل التنفيذ. قاعدة البيانات تظل هي صاحبة قرار السماح عبر RLS، وليس إخفاء الزر فقط.
- حذف صورة المريض يحذف الملف من Storage وسجله من `patient_images`. حذف ملف مريض يحذف صوره وسجل زياراته وبياناته الخاصة التابعة تلقائيًا، لكنه يُمنع إذا كان المريض مرتبطًا بعملية زراعة أو حركة مالية حتى لا تضيع المراجع الطبية/المالية.
- حذف موعد أو عملية لا يمسح قيود دفتر الحسابات المرتبطة؛ تُفصل العلاقة ويظل القيد المالي محفوظًا. حذف حركة مالية منفردة متاح للـ Admin بعد التأكيد.
- حذف المستخدم يتم من خلال API server-side باستخدام `SUPABASE_SERVICE_ROLE_KEY`، مع التحقق من جلسة Admin والمؤسسة، ومنع حذف الحساب الحالي أو آخر Admin نشط. مراجع المستخدم في السجلات التاريخية تُحوّل إلى NULL حيث تسمح بنية الجدول.

### تطبيق Migration الجديد
نفّذ ملف `supabase/migrations/0007_permanent_delete_support.sql` على مشروع Supabase قبل استخدام حذف المستخدمين. لا تضع Service Role Key في متغير يبدأ بـ `NEXT_PUBLIC_` ولا ترفعه إلى GitHub؛ ضعه في Environment Variables في Vercel وفي `.env.local` محليًا فقط.
