-- ============================================================
-- FIXIS PRO v1.9.2.0
-- MIGRATION 022
-- WEEKLY SETTLEMENTS BACKEND
-- ============================================================
-- Objetivo:
--   - Crear liquidaciones semanales desde earnings disponibles.
--   - Mantener asignación FIFO existente.
--   - Evitar doble pago mediante settlement_items.
--   - Exponer solo wrappers seguros al rol authenticated/admin.
--   - Mantener funciones trusted fuera del cliente Flutter.
--
-- NOTA:
-- Esta migración NO instala pg_cron.
-- El corte puede dispararse manualmente desde Admin.
-- La automatización de viernes puede añadirse después de validar.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. CAMPOS DE TRAZABILIDAD
-- ------------------------------------------------------------

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS scheduled_for date;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS generated_by uuid;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS processed_by uuid;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS paid_by uuid;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS rejected_by uuid;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS payout_reference text;

ALTER TABLE public.settlements
ADD COLUMN IF NOT EXISTS payment_notes text;

CREATE INDEX IF NOT EXISTS idx_settlements_scheduled_for
ON public.settlements(scheduled_for);

CREATE INDEX IF NOT EXISTS idx_settlements_status_created
ON public.settlements(status, created_at);


-- ------------------------------------------------------------
-- 2. TRUSTED: GENERAR CORTE SEMANAL
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_weekly_settlements_trusted(
    p_cutoff_at timestamptz DEFAULT now(),
    p_scheduled_for date DEFAULT CURRENT_DATE,
    p_generated_by uuid DEFAULT NULL
)
RETURNS SETOF public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_account public.financial_accounts;
    v_profile public.profiles;
    v_settlement public.settlements;
    v_available numeric(12,2);
    v_remaining numeric(12,2);
    v_allocatable numeric(12,2);
    v_already_allocated numeric(12,2);
    v_entry record;
BEGIN
    FOR v_account IN
        SELECT fa.*
        FROM public.financial_accounts fa
        WHERE fa.account_type = 'professional_payable'
          AND fa.active = true
          AND fa.professional_id IS NOT NULL
        ORDER BY fa.professional_id
        FOR UPDATE
    LOOP
        SELECT *
        INTO v_profile
        FROM public.profiles
        WHERE id = v_account.professional_id;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        IF v_profile.role <> 'professional'
           OR v_profile.verification_status <> 'approved'
           OR v_profile.account_status <> 'active'
        THEN
            CONTINUE;
        END IF;

        -- Sin datos de pago no generamos una liquidación incompleta.
        IF COALESCE(TRIM(v_profile.bank), '') = ''
           OR COALESCE(TRIM(v_profile.account_type), '') = ''
           OR COALESCE(TRIM(v_profile.account_number), '') = ''
        THEN
            CONTINUE;
        END IF;

        -- Disponible real hasta el corte:
        -- earnings - allocations ya comprometidas/pagadas.
        SELECT COALESCE(
            SUM(
                le.amount
                -
                COALESCE(
                    (
                        SELECT SUM(si.allocated_amount)
                        FROM public.settlement_items si
                        JOIN public.settlements s
                          ON s.id = si.settlement_id
                        WHERE si.ledger_entry_id = le.id
                          AND s.status IN ('requested', 'processing', 'paid')
                    ),
                    0
                )
            ),
            0
        )
        INTO v_available
        FROM public.financial_ledger_entries le
        WHERE le.account_id = v_account.id
          AND le.entry_type = 'professional_earning'
          AND le.direction = 'credit'
          AND le.status = 'available'
          AND le.created_at <= p_cutoff_at;

        v_available := ROUND(COALESCE(v_available, 0), 2);

        IF v_available <= 0 THEN
            CONTINUE;
        END IF;

        INSERT INTO public.settlements (
            professional_id,
            account_id,
            requested_amount,
            currency,
            status,
            bank_name,
            bank_account_type,
            bank_account_number,
            scheduled_for,
            generated_by
        )
        VALUES (
            v_account.professional_id,
            v_account.id,
            v_available,
            'USD',
            'requested',
            v_profile.bank,
            v_profile.account_type,
            v_profile.account_number,
            p_scheduled_for,
            p_generated_by
        )
        RETURNING *
        INTO v_settlement;

        v_remaining := v_available;

        FOR v_entry IN
            SELECT le.id, le.amount, le.created_at
            FROM public.financial_ledger_entries le
            WHERE le.account_id = v_account.id
              AND le.entry_type = 'professional_earning'
              AND le.direction = 'credit'
              AND le.status = 'available'
              AND le.created_at <= p_cutoff_at
            ORDER BY le.created_at, le.id
            FOR UPDATE
        LOOP
            SELECT COALESCE(SUM(si.allocated_amount), 0)
            INTO v_already_allocated
            FROM public.settlement_items si
            JOIN public.settlements s
              ON s.id = si.settlement_id
            WHERE si.ledger_entry_id = v_entry.id
              AND s.status IN ('requested', 'processing', 'paid');

            v_allocatable :=
                ROUND(v_entry.amount - COALESCE(v_already_allocated, 0), 2);

            IF v_allocatable <= 0 THEN
                CONTINUE;
            END IF;

            INSERT INTO public.settlement_items (
                settlement_id,
                ledger_entry_id,
                allocated_amount
            )
            VALUES (
                v_settlement.id,
                v_entry.id,
                LEAST(v_remaining, v_allocatable)
            );

            v_remaining :=
                ROUND(v_remaining - LEAST(v_remaining, v_allocatable), 2);

            EXIT WHEN v_remaining <= 0;
        END LOOP;

        IF v_remaining > 0 THEN
            RAISE EXCEPTION 'SETTLEMENT_ALLOCATION_INCOMPLETE';
        END IF;

        RETURN NEXT v_settlement;
    END LOOP;

    RETURN;
END;
$$;


-- ------------------------------------------------------------
-- 3. ADMIN: GENERAR CORTE
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_create_weekly_settlements(
    p_cutoff_at timestamptz DEFAULT now(),
    p_scheduled_for date DEFAULT CURRENT_DATE
)
RETURNS SETOF public.settlements
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
    SELECT *
    FROM public.create_weekly_settlements_trusted(
        p_cutoff_at,
        p_scheduled_for,
        v_user_id
    );
END;
$$;


-- ------------------------------------------------------------
-- 4. ADMIN: PASAR A PROCESSING
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_mark_settlement_processing(
    p_settlement_id uuid
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
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;

    IF NOT FOUND OR v_profile.role <> 'admin'
       OR v_profile.account_status <> 'active'
    THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    SELECT *
    INTO v_result
    FROM public.mark_settlement_processing_trusted(p_settlement_id);

    UPDATE public.settlements
    SET processed_by = COALESCE(processed_by, v_user_id)
    WHERE id = p_settlement_id
    RETURNING *
    INTO v_result;

    RETURN v_result;
END;
$$;


-- ------------------------------------------------------------
-- 5. ADMIN: MARCAR PAGADO
-- ------------------------------------------------------------

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
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;

    IF NOT FOUND OR v_profile.role <> 'admin'
       OR v_profile.account_status <> 'active'
    THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    -- La función trusted valida el estado y genera settlement_debit idempotente.
    SELECT *
    INTO v_result
    FROM public.mark_settlement_paid_trusted(p_settlement_id);

    UPDATE public.settlements
    SET
        paid_by = COALESCE(paid_by, v_user_id),
        payout_reference = NULLIF(TRIM(p_payout_reference), ''),
        payment_notes = NULLIF(TRIM(p_notes), '')
    WHERE id = p_settlement_id
    RETURNING *
    INTO v_result;

    RETURN v_result;
END;
$$;


-- ------------------------------------------------------------
-- 6. ADMIN: RECHAZAR
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_reject_settlement(
    p_settlement_id uuid,
    p_reason text,
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
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    IF NULLIF(TRIM(p_reason), '') IS NULL THEN
        RAISE EXCEPTION 'REJECTION_REASON_REQUIRED';
    END IF;

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;

    IF NOT FOUND OR v_profile.role <> 'admin'
       OR v_profile.account_status <> 'active'
    THEN
        RAISE EXCEPTION 'ADMIN_REQUIRED';
    END IF;

    SELECT *
    INTO v_result
    FROM public.reject_settlement_trusted(
        p_settlement_id,
        TRIM(p_reason)
    );

    UPDATE public.settlements
    SET
        rejected_by = COALESCE(rejected_by, v_user_id),
        payment_notes = NULLIF(TRIM(p_notes), '')
    WHERE id = p_settlement_id
    RETURNING *
    INTO v_result;

    RETURN v_result;
END;
$$;


-- ------------------------------------------------------------
-- 7. ADMIN READ ACCESS
-- ------------------------------------------------------------

DROP POLICY IF EXISTS settlements_select_admin
ON public.settlements;

CREATE POLICY settlements_select_admin
ON public.settlements
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

DROP POLICY IF EXISTS settlement_items_select_admin
ON public.settlement_items;

CREATE POLICY settlement_items_select_admin
ON public.settlement_items
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'admin'
          AND p.account_status = 'active'
    )
);

GRANT SELECT ON public.settlements TO authenticated;
GRANT SELECT ON public.settlement_items TO authenticated;


-- ------------------------------------------------------------
-- 8. EXECUTE PERMISSIONS
-- ------------------------------------------------------------

REVOKE EXECUTE
ON FUNCTION public.create_weekly_settlements_trusted(
    timestamptz, date, uuid
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.create_weekly_settlements_trusted(
    timestamptz, date, uuid
)
TO service_role, postgres;


REVOKE EXECUTE
ON FUNCTION public.admin_create_weekly_settlements(
    timestamptz, date
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_create_weekly_settlements(
    timestamptz, date
)
TO authenticated, service_role, postgres;


REVOKE EXECUTE
ON FUNCTION public.admin_mark_settlement_processing(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_mark_settlement_processing(uuid)
TO authenticated, service_role, postgres;


REVOKE EXECUTE
ON FUNCTION public.admin_mark_settlement_paid(uuid, text, text)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_mark_settlement_paid(uuid, text, text)
TO authenticated, service_role, postgres;


REVOKE EXECUTE
ON FUNCTION public.admin_reject_settlement(uuid, text, text)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.admin_reject_settlement(uuid, text, text)
TO authenticated, service_role, postgres;


-- Mantener trusted settlement RPCs fuera del cliente.
REVOKE EXECUTE
ON FUNCTION public.mark_settlement_processing_trusted(uuid)
FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE
ON FUNCTION public.mark_settlement_paid_trusted(uuid)
FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE
ON FUNCTION public.reject_settlement_trusted(uuid, text)
FROM PUBLIC, anon, authenticated;

COMMIT;
