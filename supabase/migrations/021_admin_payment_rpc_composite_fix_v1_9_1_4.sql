-- ============================================================
-- FIXIS PRO v1.9.1.4
-- Migration 021
-- Admin Payment RPC Composite Return Fix
--
-- Corrige:
--   admin_verify_bank_transfer(...)
--   admin_reject_bank_transfer(...)
--
-- Causa:
-- Las funciones trusted retornan public.payments (tipo compuesto).
-- El patrón anterior:
--
--   SELECT public.func(...) INTO v_payment;
--
-- trataba el resultado compuesto como una sola columna y PostgreSQL
-- intentaba convertir el record completo al primer campo del composite
-- (uuid), causando:
--
--   invalid input syntax for type uuid: "(...)"
--
-- Solución:
--
--   SELECT *
--   INTO v_payment
--   FROM public.func(...);
--
-- No cambia reglas de negocio, RLS ni permisos de los trusted RPC.
-- ============================================================

BEGIN;


-- ------------------------------------------------------------
-- 1. ADMIN VERIFY BANK TRANSFER
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

    SELECT *
    INTO v_payment
    FROM public.verify_bank_transfer_trusted(
        p_payment_id,
        p_amount_confirmed,
        p_bank_reference,
        p_bank_transaction_id,
        v_user_id,
        p_notes
    );

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
-- 2. ADMIN REJECT BANK TRANSFER
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

    SELECT *
    INTO v_payment
    FROM public.reject_bank_transfer_trusted(
        p_payment_id,
        p_reason,
        v_user_id,
        p_notes
    );

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
-- 3. KEEP TRUSTED RPCS PRIVATE
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
