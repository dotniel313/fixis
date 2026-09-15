-- ============================================================
-- FIXIS PRO v1.9.3.0
-- MIGRATION 026
-- PROFESSIONAL WALLET / WEEKLY PAYOUT FOUNDATION
-- ============================================================
-- El modelo operativo pasa a:
-- available -> weekly Friday cut -> requested -> processing -> paid
--
-- No elimina request_withdrawal/cancel_withdrawal para mantener
-- compatibilidad con solicitudes manuales históricas.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_professional_payout_schedule()
RETURNS TABLE (
    next_cut_date date,
    active_settlement_id uuid,
    active_settlement_amount numeric,
    active_settlement_status text,
    active_scheduled_for date,
    last_paid_amount numeric,
    last_paid_at timestamptz,
    last_payout_reference text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_local_date date;
    v_isodow integer;
    v_next_friday date;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PROFILE_NOT_FOUND';
    END IF;

    IF v_profile.role <> 'professional' THEN
        RAISE EXCEPTION 'NOT_A_PROFESSIONAL';
    END IF;

    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    -- Calendario operativo Ecuador.
    v_local_date := timezone('America/Guayaquil', now())::date;
    v_isodow := extract(isodow from v_local_date)::integer;
    v_next_friday :=
        v_local_date + ((5 - v_isodow + 7) % 7);

    RETURN QUERY
    WITH active_settlement AS (
        SELECT
            s.id,
            s.requested_amount,
            s.status,
            s.scheduled_for
        FROM public.settlements s
        WHERE s.professional_id = v_user_id
          AND s.status IN ('requested', 'processing')
        ORDER BY
            CASE WHEN s.status = 'processing' THEN 0 ELSE 1 END,
            s.created_at DESC
        LIMIT 1
    ),
    last_paid AS (
        SELECT
            s.requested_amount,
            s.paid_at,
            s.payout_reference
        FROM public.settlements s
        WHERE s.professional_id = v_user_id
          AND s.status = 'paid'
        ORDER BY s.paid_at DESC NULLS LAST, s.created_at DESC
        LIMIT 1
    )
    SELECT
        v_next_friday,
        a.id,
        a.requested_amount,
        a.status,
        a.scheduled_for,
        lp.requested_amount,
        lp.paid_at,
        lp.payout_reference
    FROM (SELECT 1) x
    LEFT JOIN active_settlement a ON true
    LEFT JOIN last_paid lp ON true;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.get_professional_payout_schedule()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.get_professional_payout_schedule()
TO authenticated, service_role, postgres;

COMMIT;
