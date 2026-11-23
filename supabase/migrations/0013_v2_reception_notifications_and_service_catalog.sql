-- V2 follow-up: grant Reception limited financial recording capabilities.
-- Reception can read branch transactions and add only linked patient/appointment/operation entries
-- per existing policy logic; administrative reporting and deletes remain Admin/Finance-controlled.
-- Note: module access gates must still be configured for Reception finance module in profiles.permissions.
DROP POLICY IF EXISTS finance_insert ON public.financial_transactions;
CREATE POLICY finance_insert ON public.financial_transactions FOR INSERT TO authenticated WITH CHECK (
  private.can_access_branch(organization_id,branch_id) AND (
    private.is_admin(organization_id)
    OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='finance')
    OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role='reception'
       AND (appointment_id IS NOT NULL OR operation_id IS NOT NULL OR patient_id IS NOT NULL)
  )
);
-- Notification visibility: branch users can read notices; Admin may acknowledge notices.
DROP POLICY IF EXISTS finance_notifications_admin_update ON public.finance_notifications;
CREATE POLICY finance_notifications_admin_update ON public.finance_notifications FOR UPDATE TO authenticated
USING (private.is_admin(organization_id)) WITH CHECK (private.is_admin(organization_id));
