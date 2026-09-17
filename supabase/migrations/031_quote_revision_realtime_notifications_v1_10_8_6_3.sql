-- FIXIS PRO v1.10.8.6.3
-- Revised Quote realtime + professional notifications
-- Date: 2026-09-17
--
-- Goals:
--   1. Publish jobs changes through Supabase Realtime.
--   2. Notify the assigned professional when a quote revision is accepted
--      or rejected by the customer.
--   3. Keep notification creation idempotent and backend-authoritative.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Notification types
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check
CHECK (
    type IN (
        'settlement_created',
        'settlement_processing',
        'settlement_paid',
        'settlement_rejected',
        'quote_revision_accepted',
        'quote_revision_rejected'
    )
);

-- ---------------------------------------------------------------------------
-- 2. Backend-authoritative quote revision notification
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_quote_revision_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_type text;
    v_title text;
    v_body text;
    v_idempotency_key text;
BEGIN
    -- Only revised quotes have a parent_quote_id.
    IF NEW.parent_quote_id IS NULL
       OR OLD.status IS NOT DISTINCT FROM NEW.status
       OR NEW.status NOT IN ('accepted', 'rejected')
    THEN
        RETURN NEW;
    END IF;

    IF NEW.status = 'accepted' THEN
        v_type := 'quote_revision_accepted';
        v_title := 'Nuevo alcance aceptado';
        v_body :=
            'El cliente aceptó el nuevo alcance. Ya puedes iniciar el trabajo.';
        v_idempotency_key :=
            'JOB:' || NEW.job_id::text ||
            ':QUOTE_REVISION:' || NEW.id::text ||
            ':ACCEPTED';
    ELSE
        v_type := 'quote_revision_rejected';
        v_title := 'Nuevo alcance rechazado';
        v_body :=
            'El cliente rechazó el nuevo alcance. Se mantiene la cotización anterior.';
        v_idempotency_key :=
            'JOB:' || NEW.job_id::text ||
            ':QUOTE_REVISION:' || NEW.id::text ||
            ':REJECTED';
    END IF;

    INSERT INTO public.notifications (
        user_id,
        type,
        title,
        body,
        job_id,
        idempotency_key
    )
    VALUES (
        NEW.professional_id,
        v_type,
        v_title,
        v_body,
        NEW.job_id,
        v_idempotency_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$function$;

REVOKE EXECUTE
ON FUNCTION public.handle_quote_revision_notification()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.handle_quote_revision_notification()
TO service_role, postgres;

DROP TRIGGER IF EXISTS quote_revision_notification_trigger
ON public.quotes;

CREATE TRIGGER quote_revision_notification_trigger
AFTER UPDATE OF status
ON public.quotes
FOR EACH ROW
EXECUTE FUNCTION public.handle_quote_revision_notification();

-- ---------------------------------------------------------------------------
-- 3. Realtime jobs publication
-- ---------------------------------------------------------------------------

DO $realtime$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'jobs'
    ) THEN
        ALTER PUBLICATION supabase_realtime
        ADD TABLE public.jobs;
    END IF;
END
$realtime$;

COMMIT;

-- Post-apply checks:
--
-- SELECT *
-- FROM pg_publication_tables
-- WHERE pubname = 'supabase_realtime'
--   AND schemaname = 'public'
--   AND tablename IN ('jobs', 'notifications');
--
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'public.notifications'::regclass
--   AND conname = 'notifications_type_check';
