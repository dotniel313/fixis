BEGIN;

-- ============================================================
-- FIXIS PRO v1.10.8.6.2
-- MIGRATION 030
-- ADMIN PAYMENTS ENRICHED AMBIGUITY FIX
-- ============================================================
-- Objetivo:
-- - Corregir error 42702 en admin_get_payments_enriched().
-- - El RETURNS TABLE declara una columna de salida llamada "id" y
--   PL/pgSQL la expone como variable, por lo que "WHERE id = ..."
--   resulta ambiguo frente a profiles.id.
-- - No modifica pagos, ledger, liquidaciones, comisiones,
--   revised quotes ni estados financieros.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_get_payments_enriched(
    p_statuses text[],
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    id uuid,
    job_id uuid,
    customer_id uuid,
    professional_id uuid,
    snapshot_id uuid,
    payment_method text,
    status text,
    currency text,
    service_amount numeric,
    customer_fee_amount numeric,
    total_due numeric,
    amount_received numeric,
    reference_code text,
    provider text,
    provider_payment_id text,
    provider_transaction_id text,
    customer_approved_at timestamptz,
    paid_at timestamptz,
    verified_at timestamptz,
    verified_by uuid,
    rejected_at timestamptz,
    rejection_reason text,
    refunded_at timestamptz,
    created_at timestamptz,
    updated_at timestamptz,
    job_title text,
    job_category text,
    job_address text,
    customer_name text,
    professional_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_limit integer;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT pr.*
    INTO v_profile
    FROM public.profiles AS pr
    WHERE pr.id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PROFILE_NOT_FOUND';
    END IF;

    IF v_profile.role <> 'admin' THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    RETURN QUERY
    SELECT
        p.id,
        p.job_id,
        p.customer_id,
        p.professional_id,
        p.snapshot_id,
        p.payment_method,
        p.status,
        p.currency,
        p.service_amount,
        p.customer_fee_amount,
        p.total_due,
        p.amount_received,
        p.reference_code,
        p.provider,
        p.provider_payment_id,
        p.provider_transaction_id,
        p.customer_approved_at,
        p.paid_at,
        p.verified_at,
        p.verified_by,
        p.rejected_at,
        p.rejection_reason,
        p.refunded_at,
        p.created_at,
        p.updated_at,
        j.title,
        j.category,
        j.address,
        customer.full_name,
        professional.full_name
    FROM public.payments AS p
    JOIN public.jobs AS j
      ON j.id = p.job_id
    JOIN public.profiles AS customer
      ON customer.id = p.customer_id
    JOIN public.profiles AS professional
      ON professional.id = p.professional_id
    WHERE p_statuses IS NULL
       OR array_length(p_statuses, 1) IS NULL
       OR p.status = ANY (p_statuses)
    ORDER BY p.created_at DESC
    LIMIT v_limit;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.admin_get_payments_enriched(text[], integer)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_get_payments_enriched(text[], integer)
TO authenticated;

COMMENT ON FUNCTION public.admin_get_payments_enriched(text[], integer)
IS 'Admin-only read RPC for enriched payment rows; v1.10.8.6.2 resolves PL/pgSQL id ambiguity.';

COMMIT;
