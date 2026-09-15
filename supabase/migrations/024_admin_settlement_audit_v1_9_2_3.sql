-- ============================================================
-- FIXIS PRO v1.9.2.3
-- MIGRATION 024
-- ADMIN SETTLEMENT AUDIT & TRACEABILITY
-- ============================================================
-- Objetivo:
--   - Auditar liquidaciones sin exponer funciones trusted.
--   - Confirmar:
--       1) suma de settlement_items
--       2) cantidad de settlement_debit
--       3) monto debitado
--       4) consistencia final de liquidaciones paid
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_get_settlement_audit(
    p_limit integer DEFAULT 50
)
RETURNS TABLE (
    settlement_id uuid,
    professional_id uuid,
    professional_name text,
    requested_amount numeric,
    status text,
    scheduled_for date,
    payout_reference text,
    created_at timestamptz,
    paid_at timestamptz,
    allocated_amount numeric,
    settlement_debit_count bigint,
    settlement_debit_amount numeric,
    audit_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
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

    IF v_profile.role <> 'admin' THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    RETURN QUERY
    WITH item_totals AS (
        SELECT
            si.settlement_id,
            COALESCE(SUM(si.allocated_amount), 0)::numeric AS allocated_amount
        FROM public.settlement_items si
        GROUP BY si.settlement_id
    ),
    debit_totals AS (
        SELECT
            le.settlement_id,
            COUNT(*)::bigint AS debit_count,
            COALESCE(SUM(le.amount), 0)::numeric AS debit_amount
        FROM public.financial_ledger_entries le
        WHERE le.entry_type = 'settlement_debit'
          AND le.direction = 'debit'
          AND le.settlement_id IS NOT NULL
        GROUP BY le.settlement_id
    )
    SELECT
        s.id,
        s.professional_id,
        s.professional_name,
        s.requested_amount,
        s.status,
        s.scheduled_for,
        s.payout_reference,
        s.created_at,
        s.paid_at,
        COALESCE(it.allocated_amount, 0),
        COALESCE(dt.debit_count, 0),
        COALESCE(dt.debit_amount, 0),
        CASE
            WHEN s.status = 'paid'
                 AND COALESCE(it.allocated_amount, 0) = s.requested_amount
                 AND COALESCE(dt.debit_count, 0) = 1
                 AND COALESCE(dt.debit_amount, 0) = s.requested_amount
                THEN 'ok'

            WHEN s.status = 'paid'
                THEN 'review'

            WHEN s.status IN ('requested', 'processing')
                 AND COALESCE(it.allocated_amount, 0) = s.requested_amount
                 AND COALESCE(dt.debit_count, 0) = 0
                THEN 'reserved'

            WHEN s.status IN ('rejected', 'cancelled')
                 AND COALESCE(dt.debit_count, 0) = 0
                THEN 'closed_without_debit'

            ELSE 'review'
        END AS audit_status
    FROM public.settlements s
    LEFT JOIN item_totals it
      ON it.settlement_id = s.id
    LEFT JOIN debit_totals dt
      ON dt.settlement_id = s.id
    ORDER BY s.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.admin_get_settlement_audit(integer)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_get_settlement_audit(integer)
TO authenticated, service_role, postgres;

COMMIT;
