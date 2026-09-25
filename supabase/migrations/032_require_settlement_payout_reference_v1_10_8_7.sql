BEGIN;

-- A bank payout must be traceable before the administrator closes a settlement.
-- Existing paid settlements are left untouched; repeated calls stay idempotent.
CREATE OR REPLACE FUNCTION public.admin_mark_settlement_paid(
    p_settlement_id uuid,
    p_payout_reference text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_result public.settlements;
    v_reference text;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT * INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;

    IF NOT FOUND OR v_profile.role <> 'admin'
       OR v_profile.account_status <> 'active'
    THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    SELECT * INTO v_result
    FROM public.settlements
    WHERE id = p_settlement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;

    IF v_result.status = 'paid' THEN
        RETURN v_result;
    END IF;

    v_reference := NULLIF(BTRIM(p_payout_reference), '');
    IF v_reference IS NULL THEN
        RAISE EXCEPTION 'PAYOUT_REFERENCE_REQUIRED';
    END IF;

    -- The trusted function checks the state and writes an idempotent debit.
    SELECT * INTO v_result
    FROM public.mark_settlement_paid_trusted(p_settlement_id);

    UPDATE public.settlements
    SET paid_by = COALESCE(paid_by, v_user_id),
        payout_reference = v_reference,
        payment_notes = NULLIF(BTRIM(p_notes), '')
    WHERE id = p_settlement_id
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_mark_settlement_paid(uuid, text, text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_mark_settlement_paid(uuid, text, text)
TO authenticated, service_role, postgres;

COMMIT;
