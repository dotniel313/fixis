BEGIN;

-- ============================================================
-- FIXIS PRO v1.9.1
-- MIGRATION 020
-- ADMIN PAYMENT RECONCILIATION
-- ============================================================
-- Objetivo:
-- - Permitir que un perfil role='admin' gestione pagos pendientes
--   desde la app SIN exponer service_role.
-- - El admin puede leer pagos/evidencias.
-- - Las confirmaciones/rechazos pasan por RPCs SECURITY DEFINER
--   que validan role + account_status.
-- - Los RPC trusted originales siguen bloqueados para authenticated.
-- ============================================================

-- ------------------------------------------------------------
-- 1. ADMIN READ POLICIES
-- ------------------------------------------------------------

DROP POLICY IF EXISTS payments_select_admin
ON public.payments;

CREATE POLICY payments_select_admin
ON public.payments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

DROP POLICY IF EXISTS payment_evidence_select_admin
ON public.payment_evidence;

CREATE POLICY payment_evidence_select_admin
ON public.payment_evidence
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

DROP POLICY IF EXISTS payment_allocations_select_admin
ON public.payment_allocations;

CREATE POLICY payment_allocations_select_admin
ON public.payment_allocations
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

DROP POLICY IF EXISTS payment_reconciliation_select_admin
ON public.payment_reconciliation;

CREATE POLICY payment_reconciliation_select_admin
ON public.payment_reconciliation
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

-- payment_reconciliation previously had no authenticated table grant.
-- Admin needs read-only access through RLS.
GRANT SELECT ON TABLE public.payment_reconciliation TO authenticated;


-- ------------------------------------------------------------
-- 2. STORAGE: ADMIN MAY READ PRIVATE VOUCHERS
-- ------------------------------------------------------------

DROP POLICY IF EXISTS payment_evidence_storage_select_admin
ON storage.objects;

CREATE POLICY payment_evidence_storage_select_admin
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'payment-evidence'
    AND EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);


-- ------------------------------------------------------------
-- 3. ADMIN RPC: VERIFY BANK TRANSFER
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_verify_bank_transfer(
    p_payment_id uuid,
    p_amount_confirmed numeric,
    p_bank_reference text DEFAULT NULL,
    p_bank_transaction_id text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_payment public.payments;
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

    SELECT public.verify_bank_transfer_trusted(
        p_payment_id,
        p_amount_confirmed,
        p_bank_reference,
        p_bank_transaction_id,
        v_user_id,
        p_notes
    )
    INTO v_payment;

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.admin_verify_bank_transfer(
    uuid, numeric, text, text, text
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_verify_bank_transfer(
    uuid, numeric, text, text, text
)
TO authenticated;


-- ------------------------------------------------------------
-- 4. ADMIN RPC: REJECT BANK TRANSFER
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_reject_bank_transfer(
    p_payment_id uuid,
    p_reason text,
    p_notes text DEFAULT NULL
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_payment public.payments;
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

    SELECT public.reject_bank_transfer_trusted(
        p_payment_id,
        p_reason,
        v_user_id,
        p_notes
    )
    INTO v_payment;

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.admin_reject_bank_transfer(
    uuid, text, text
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_reject_bank_transfer(
    uuid, text, text
)
TO authenticated;


-- ------------------------------------------------------------
-- 5. ENSURE TRUSTED RPCS STAY PRIVATE
-- ------------------------------------------------------------

REVOKE EXECUTE
ON FUNCTION public.verify_bank_transfer_trusted(
    uuid, numeric, text, text, uuid, text
)
FROM authenticated, anon, PUBLIC;

REVOKE EXECUTE
ON FUNCTION public.reject_bank_transfer_trusted(
    uuid, text, uuid, text
)
FROM authenticated, anon, PUBLIC;

COMMIT;
