-- ============================================================
-- FIXIS PRO v1.9.3.1
-- MIGRATION 027
-- REAL SETTLEMENT NOTIFICATIONS
-- ============================================================
-- Real event source:
--   settlements INSERT / status transitions
--
-- Events:
--   settlement_created
--   settlement_processing
--   settlement_paid
--   settlement_rejected
--
-- Client may SELECT its own notifications and update read_at only.
-- No client INSERT/DELETE.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL
        REFERENCES public.profiles(id)
        ON DELETE CASCADE,
    type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    settlement_id uuid
        REFERENCES public.settlements(id)
        ON DELETE SET NULL,
    job_id uuid
        REFERENCES public.jobs(id)
        ON DELETE SET NULL,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    idempotency_key text NOT NULL UNIQUE,
    CONSTRAINT notifications_type_check CHECK (
        type IN (
            'settlement_created',
            'settlement_processing',
            'settlement_paid',
            'settlement_rejected'
        )
    )
);

CREATE INDEX IF NOT EXISTS notifications_user_created_idx
ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_user_unread_idx
ON public.notifications(user_id, read_at)
WHERE read_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own
ON public.notifications;

CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own
ON public.notifications;

CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role, postgres;


CREATE OR REPLACE FUNCTION public.handle_settlement_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_amount text;
    v_ref text;
BEGIN
    v_amount := to_char(NEW.requested_amount, 'FM999999990.00');

    -- Weekly/admin-generated settlement prepared.
    IF TG_OP = 'INSERT'
       AND NEW.status = 'requested'
       AND NEW.generated_by IS NOT NULL
    THEN
        INSERT INTO public.notifications (
            user_id,
            type,
            title,
            body,
            settlement_id,
            idempotency_key
        )
        VALUES (
            NEW.professional_id,
            'settlement_created',
            'Tu liquidación está preparada',
            'FIXIS reservó $' || v_amount ||
                ' para tu próxima transferencia'
                || CASE
                    WHEN NEW.scheduled_for IS NOT NULL
                    THEN ' programada para ' || NEW.scheduled_for::text || '.'
                    ELSE '.'
                   END,
            NEW.id,
            'SETTLEMENT:' || NEW.id::text || ':NOTIFY:CREATED'
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.status IS DISTINCT FROM NEW.status
    THEN
        IF NEW.status = 'processing' THEN
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                body,
                settlement_id,
                idempotency_key
            )
            VALUES (
                NEW.professional_id,
                'settlement_processing',
                'Tu pago está en procesamiento',
                'FIXIS está procesando tu transferencia por $'
                    || v_amount || '.',
                NEW.id,
                'SETTLEMENT:' || NEW.id::text || ':NOTIFY:PROCESSING'
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

        ELSIF NEW.status = 'paid' THEN
            v_ref := NULLIF(TRIM(COALESCE(NEW.payout_reference, '')), '');

            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                body,
                settlement_id,
                idempotency_key
            )
            VALUES (
                NEW.professional_id,
                'settlement_paid',
                'Transferencia realizada',
                'FIXIS registró el pago de $' || v_amount
                    || CASE
                        WHEN v_ref IS NOT NULL
                        THEN '. Referencia: ' || v_ref || '.'
                        ELSE '.'
                       END,
                NEW.id,
                'SETTLEMENT:' || NEW.id::text || ':NOTIFY:PAID'
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

        ELSIF NEW.status = 'rejected' THEN
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                body,
                settlement_id,
                idempotency_key
            )
            VALUES (
                NEW.professional_id,
                'settlement_rejected',
                'Liquidación requiere revisión',
                'La liquidación por $' || v_amount ||
                    ' no pudo continuar. Revisa tus datos de pago o contacta a FIXIS.',
                NEW.id,
                'SETTLEMENT:' || NEW.id::text || ':NOTIFY:REJECTED'
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.handle_settlement_notification()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.handle_settlement_notification()
TO service_role, postgres;

DROP TRIGGER IF EXISTS settlement_notification_trigger
ON public.settlements;

CREATE TRIGGER settlement_notification_trigger
AFTER INSERT OR UPDATE OF status
ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.handle_settlement_notification();


-- ------------------------------------------------------------
-- Historical real-event backfill.
-- Only current meaningful payout states are materialized.
-- Idempotency makes this safe to rerun.
-- ------------------------------------------------------------

INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    settlement_id,
    read_at,
    created_at,
    idempotency_key
)
SELECT
    s.professional_id,
    CASE
        WHEN s.status = 'paid' THEN 'settlement_paid'
        WHEN s.status = 'processing' THEN 'settlement_processing'
        WHEN s.status = 'requested' THEN 'settlement_created'
        WHEN s.status = 'rejected' THEN 'settlement_rejected'
    END,
    CASE
        WHEN s.status = 'paid' THEN 'Transferencia realizada'
        WHEN s.status = 'processing' THEN 'Tu pago está en procesamiento'
        WHEN s.status = 'requested' THEN 'Tu liquidación está preparada'
        WHEN s.status = 'rejected' THEN 'Liquidación requiere revisión'
    END,
    CASE
        WHEN s.status = 'paid' THEN
            'FIXIS registró el pago de $'
            || to_char(s.requested_amount, 'FM999999990.00')
            || CASE
                WHEN NULLIF(TRIM(COALESCE(s.payout_reference, '')), '') IS NOT NULL
                THEN '. Referencia: ' || s.payout_reference || '.'
                ELSE '.'
               END
        WHEN s.status = 'processing' THEN
            'FIXIS está procesando tu transferencia por $'
            || to_char(s.requested_amount, 'FM999999990.00') || '.'
        WHEN s.status = 'requested' THEN
            'FIXIS reservó $'
            || to_char(s.requested_amount, 'FM999999990.00')
            || ' para tu próxima transferencia'
            || CASE
                WHEN s.scheduled_for IS NOT NULL
                THEN ' programada para ' || s.scheduled_for::text || '.'
                ELSE '.'
               END
        ELSE
            'La liquidación por $'
            || to_char(s.requested_amount, 'FM999999990.00')
            || ' no pudo continuar. Revisa tus datos de pago o contacta a FIXIS.'
    END,
    s.id,
    NULL,
    COALESCE(s.paid_at, s.created_at),
    'SETTLEMENT:' || s.id::text || ':NOTIFY:'
        || CASE
            WHEN s.status = 'paid' THEN 'PAID'
            WHEN s.status = 'processing' THEN 'PROCESSING'
            WHEN s.status = 'requested' THEN 'CREATED'
            ELSE 'REJECTED'
           END
FROM public.settlements s
WHERE s.status IN ('paid', 'processing', 'requested', 'rejected')
ON CONFLICT (idempotency_key) DO NOTHING;


-- ------------------------------------------------------------
-- Realtime
-- ------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime
        ADD TABLE public.notifications;
    END IF;
END
$$;

COMMIT;
