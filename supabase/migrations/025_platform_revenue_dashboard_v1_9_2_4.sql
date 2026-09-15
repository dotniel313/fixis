-- ============================================================
-- FIXIS PRO v1.9.2.4
-- MIGRATION 025
-- PLATFORM REVENUE DASHBOARD & AUDIT
-- ============================================================
-- Fuente de verdad:
--   financial_accounts.account_code = 'FIXIS_REVENUE_USD'
--   financial_ledger_entries.entry_type = 'platform_commission'
--
-- No crea un saldo paralelo.
-- No cambia cálculo de comisiones.
-- No cambia pagos/liquidaciones.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. SUMMARY
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_get_platform_revenue_summary(
    p_from timestamptz,
    p_to timestamptz
)
RETURNS TABLE (
    account_id uuid,
    currency text,
    ledger_balance numeric,
    all_time_commissions numeric,
    period_commissions numeric,
    all_time_jobs bigint,
    period_jobs bigint,
    audit_ok bigint,
    audit_review bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_account public.financial_accounts;
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

    IF p_from IS NULL OR p_to IS NULL OR p_from > p_to THEN
        RAISE EXCEPTION 'INVALID_PERIOD';
    END IF;

    SELECT *
    INTO v_account
    FROM public.financial_accounts
    WHERE account_code = 'FIXIS_REVENUE_USD'
      AND account_type = 'platform_revenue'
      AND active = true
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FIXIS_REVENUE_ACCOUNT_NOT_FOUND';
    END IF;

    RETURN QUERY
    WITH commission_rows AS (
        SELECT
            le.id,
            le.job_id,
            le.snapshot_id,
            le.amount,
            le.created_at,
            fs.commission_amount AS snapshot_commission,
            COUNT(*) OVER (
                PARTITION BY le.job_id, le.snapshot_id
            ) AS commission_entries_for_source
        FROM public.financial_ledger_entries le
        JOIN public.job_financial_snapshots fs
          ON fs.id = le.snapshot_id
        WHERE le.account_id = v_account.id
          AND le.entry_type = 'platform_commission'
          AND le.direction = 'credit'
          AND le.status <> 'reversed'
    ),
    audit AS (
        SELECT
            cr.*,
            CASE
                WHEN cr.amount = cr.snapshot_commission
                 AND cr.commission_entries_for_source = 1
                    THEN 'ok'
                ELSE 'review'
            END AS audit_status
        FROM commission_rows cr
    )
    SELECT
        v_account.id,
        v_account.currency,
        COALESCE(
            (
                SELECT SUM(
                    CASE
                        WHEN le.direction = 'credit' THEN le.amount
                        ELSE -le.amount
                    END
                )
                FROM public.financial_ledger_entries le
                WHERE le.account_id = v_account.id
                  AND le.status <> 'reversed'
            ),
            0
        )::numeric AS ledger_balance,

        COALESCE(
            (SELECT SUM(a.amount) FROM audit a),
            0
        )::numeric AS all_time_commissions,

        COALESCE(
            (
                SELECT SUM(a.amount)
                FROM audit a
                WHERE a.created_at >= p_from
                  AND a.created_at <= p_to
            ),
            0
        )::numeric AS period_commissions,

        COALESCE(
            (SELECT COUNT(DISTINCT a.job_id) FROM audit a),
            0
        )::bigint AS all_time_jobs,

        COALESCE(
            (
                SELECT COUNT(DISTINCT a.job_id)
                FROM audit a
                WHERE a.created_at >= p_from
                  AND a.created_at <= p_to
            ),
            0
        )::bigint AS period_jobs,

        COALESCE(
            (
                SELECT COUNT(*)
                FROM audit a
                WHERE a.audit_status = 'ok'
            ),
            0
        )::bigint AS audit_ok,

        COALESCE(
            (
                SELECT COUNT(*)
                FROM audit a
                WHERE a.audit_status = 'review'
            ),
            0
        )::bigint AS audit_review;
END;
$$;


-- ------------------------------------------------------------
-- 2. DETAIL / AUDIT
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_get_platform_commission_entries(
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    ledger_entry_id uuid,
    job_id uuid,
    job_title text,
    professional_id uuid,
    gross_amount numeric,
    labor_amount numeric,
    materials_amount numeric,
    other_amount numeric,
    commission_basis text,
    commission_basis_amount numeric,
    commission_rate_percent numeric,
    snapshot_commission numeric,
    ledger_commission numeric,
    professional_amount numeric,
    created_at timestamptz,
    audit_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_account public.financial_accounts;
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

    SELECT *
    INTO v_account
    FROM public.financial_accounts
    WHERE account_code = 'FIXIS_REVENUE_USD'
      AND account_type = 'platform_revenue'
      AND active = true
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FIXIS_REVENUE_ACCOUNT_NOT_FOUND';
    END IF;

    RETURN QUERY
    WITH rows_with_count AS (
        SELECT
            le.id AS ledger_entry_id,
            le.job_id,
            le.snapshot_id,
            le.amount,
            le.created_at,
            COUNT(*) OVER (
                PARTITION BY le.job_id, le.snapshot_id
            ) AS source_count
        FROM public.financial_ledger_entries le
        WHERE le.account_id = v_account.id
          AND le.entry_type = 'platform_commission'
          AND le.direction = 'credit'
          AND le.status <> 'reversed'
    )
    SELECT
        r.ledger_entry_id,
        r.job_id,
        j.title,
        fs.professional_id,
        fs.gross_amount,
        fs.labor_amount,
        fs.materials_amount,
        fs.other_amount,
        fs.commission_basis,
        fs.commission_basis_amount,
        fs.commission_rate_percent,
        fs.commission_amount,
        r.amount,
        fs.professional_amount,
        r.created_at,
        CASE
            WHEN r.amount = fs.commission_amount
             AND r.source_count = 1
                THEN 'ok'
            ELSE 'review'
        END AS audit_status
    FROM rows_with_count r
    JOIN public.job_financial_snapshots fs
      ON fs.id = r.snapshot_id
    JOIN public.jobs j
      ON j.id = r.job_id
    ORDER BY r.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
END;
$$;


-- ------------------------------------------------------------
-- 3. PERMISSIONS
-- ------------------------------------------------------------

REVOKE EXECUTE
ON FUNCTION public.admin_get_platform_revenue_summary(
    timestamptz, timestamptz
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_get_platform_revenue_summary(
    timestamptz, timestamptz
)
TO authenticated, service_role, postgres;


REVOKE EXECUTE
ON FUNCTION public.admin_get_platform_commission_entries(integer)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_get_platform_commission_entries(integer)
TO authenticated, service_role, postgres;

COMMIT;
