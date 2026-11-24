# Hair Clinic OS — Service Delete Overlay

## Changed
- `app/dashboard/page.tsx`
  - Added an "إدارة الخدمات / حذف خدمة" button beside the appointment service selector.
  - Added a service-management modal listing custom services with a delete action.
  - Deletion uses a soft delete (`clinic_services.active = false`) under the existing Supabase RLS policies.
  - Removed services disappear from future service selections; historical appointments and their saved service names/prices remain unchanged.
  - If the removed service was selected in the open appointment form, the form switches back to the default consultation service.

## Database
- No migration is required.
- No table or historical appointment data is deleted.
- Existing `clinic_services` update permissions and RLS policies remain in effect. If Supabase denies the update, the UI displays the returned error.

## Apply
1. Back up your current project.
2. Extract this ZIP.
3. Copy the `app` folder into the project root (the folder containing `package.json`).
4. Allow replacing `app/dashboard/page.tsx`.
5. Deploy the updated project.

## Verification
- ZIP integrity: checked.
- TSX syntax transpilation: passed with zero diagnostics.
- Full TypeScript project check: not completed because the supplied extracted environment does not contain a complete `tsconfig`/type-definition setup.
- Supabase runtime/RLS deletion: not tested against the live database.
