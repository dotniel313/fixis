BEGIN;

-- ============================================================
-- FIXIS PRO v1.9.0
-- MIGRATION 018
-- PAYMENTS FOUNDATION
-- ============================================================
-- Objetivo:
-- 1. El cliente NO paga antes de ejecutar el servicio.
-- 2. Al terminar el trabajo, el cliente inicia el pago.
-- 3. Transferencia bancaria + voucher es el primer método MVP.
-- 4. Un voucher es evidencia, NO confirmación de pago.
-- 5. Solo una verificación trusted/service_role puede marcar PAID.
-- 6. Solamente después de PAID se ejecuta el motor financiero
--    existente approve_completed_job_trusted(), generando:
--      - professional_earning
--      - platform_commission
--      - customer_approved
-- 7. El flujo antiguo approve_completed_job() queda bloqueado
--    para authenticated para impedir saltarse el pago.
--
-- IMPORTANTE:
-- - No implementar tasas tributarias fijas aquí.
-- - No automatizar todavía payouts de viernes.
-- - Card queda modelado pero no activado.
-- ============================================================


-- ============================================================
-- 1. PAYMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    job_id uuid NOT NULL UNIQUE,
    customer_id uuid NOT NULL,
    professional_id uuid NOT NULL,
    snapshot_id uuid NOT NULL,

    payment_method text NOT NULL,
    status text NOT NULL DEFAULT 'unpaid',

    currency text NOT NULL DEFAULT 'USD',

    service_amount numeric(12,2) NOT NULL,
    customer_fee_amount numeric(12,2) NOT NULL DEFAULT 0,
    total_due numeric(12,2) NOT NULL,

    amount_received numeric(12,2) NOT NULL DEFAULT 0,

    reference_code text NOT NULL UNIQUE,

    provider text,
    provider_payment_id text,
    provider_transaction_id text,

    customer_approved_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    paid_at timestamptz,
    verified_at timestamptz,
    verified_by uuid,

    rejected_at timestamptz,
    rejection_reason text,

    refunded_at timestamptz,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    updated_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    CONSTRAINT payments_job_fk
    FOREIGN KEY (job_id)
    REFERENCES public.jobs(id)
    ON DELETE RESTRICT,

    CONSTRAINT payments_customer_fk
    FOREIGN KEY (customer_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,

    CONSTRAINT payments_professional_fk
    FOREIGN KEY (professional_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,

    CONSTRAINT payments_snapshot_fk
    FOREIGN KEY (snapshot_id)
    REFERENCES public.job_financial_snapshots(id)
    ON DELETE RESTRICT,

    CONSTRAINT payments_verified_by_fk
    FOREIGN KEY (verified_by)
    REFERENCES public.profiles(id)
    ON DELETE SET NULL,

    CONSTRAINT payments_method_check
    CHECK (
        payment_method IN (
            'bank_transfer',
            'card'
        )
    ),

    CONSTRAINT payments_status_check
    CHECK (
        status IN (
            'unpaid',
            'pending_transfer',
            'voucher_uploaded',
            'pending_verification',
            'paid',
            'rejected',
            'refunded',
            'partially_refunded'
        )
    ),

    CONSTRAINT payments_currency_check
    CHECK (currency = 'USD'),

    CONSTRAINT payments_amounts_check
    CHECK (
        service_amount > 0
        AND customer_fee_amount >= 0
        AND total_due > 0
        AND amount_received >= 0
        AND total_due = service_amount + customer_fee_amount
    )
);

CREATE INDEX IF NOT EXISTS idx_payments_customer_created
ON public.payments(customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_professional_created
ON public.payments(professional_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_status_created
ON public.payments(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_reference
ON public.payments(reference_code);


-- ============================================================
-- 2. PAYMENT EVIDENCE
-- ============================================================
-- El comprobante NO es prueba bancaria definitiva.
-- Es evidencia aportada por el cliente para conciliación.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_evidence (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    payment_id uuid NOT NULL,
    customer_id uuid NOT NULL,

    storage_path text NOT NULL,

    declared_amount numeric(12,2),
    declared_bank text,
    declared_reference text,

    uploaded_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    CONSTRAINT payment_evidence_payment_fk
    FOREIGN KEY (payment_id)
    REFERENCES public.payments(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_evidence_customer_fk
    FOREIGN KEY (customer_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_evidence_declared_amount_check
    CHECK (
        declared_amount IS NULL
        OR declared_amount > 0
    )
);

CREATE INDEX IF NOT EXISTS idx_payment_evidence_payment
ON public.payment_evidence(payment_id, uploaded_at DESC);


-- ============================================================
-- 3. PAYMENT RECONCILIATION
-- ============================================================
-- Registro de la comprobación real de acreditación.
-- Esta tabla es auditoría financiera.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_reconciliation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    payment_id uuid NOT NULL,

    result text NOT NULL,

    amount_confirmed numeric(12,2),

    bank_reference text,
    bank_transaction_id text,

    notes text,

    verified_by uuid,
    verified_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    CONSTRAINT payment_reconciliation_payment_fk
    FOREIGN KEY (payment_id)
    REFERENCES public.payments(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_reconciliation_verified_by_fk
    FOREIGN KEY (verified_by)
    REFERENCES public.profiles(id)
    ON DELETE SET NULL,

    CONSTRAINT payment_reconciliation_result_check
    CHECK (
        result IN (
            'confirmed',
            'rejected'
        )
    ),

    CONSTRAINT payment_reconciliation_amount_check
    CHECK (
        amount_confirmed IS NULL
        OR amount_confirmed >= 0
    )
);

CREATE INDEX IF NOT EXISTS idx_payment_reconciliation_payment
ON public.payment_reconciliation(payment_id, verified_at DESC);


-- ============================================================
-- 4. PAYMENT ALLOCATIONS
-- ============================================================
-- Snapshot económico de cómo se distribuye el pago confirmado.
-- No reemplaza al ledger. Sirve para trazabilidad entre:
-- payment -> frozen financial snapshot -> ledger.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_allocations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    payment_id uuid NOT NULL UNIQUE,
    job_id uuid NOT NULL,
    snapshot_id uuid NOT NULL,

    service_gross_amount numeric(12,2) NOT NULL,

    platform_commission_amount numeric(12,2) NOT NULL,
    professional_payable_amount numeric(12,2) NOT NULL,

    customer_fee_amount numeric(12,2) NOT NULL DEFAULT 0,
    provider_fee_amount numeric(12,2) NOT NULL DEFAULT 0,

    tax_amount numeric(12,2) NOT NULL DEFAULT 0,
    tax_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,

    currency text NOT NULL DEFAULT 'USD',

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    CONSTRAINT payment_allocations_payment_fk
    FOREIGN KEY (payment_id)
    REFERENCES public.payments(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_allocations_job_fk
    FOREIGN KEY (job_id)
    REFERENCES public.jobs(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_allocations_snapshot_fk
    FOREIGN KEY (snapshot_id)
    REFERENCES public.job_financial_snapshots(id)
    ON DELETE RESTRICT,

    CONSTRAINT payment_allocations_currency_check
    CHECK (currency = 'USD'),

    CONSTRAINT payment_allocations_amounts_check
    CHECK (
        service_gross_amount > 0
        AND platform_commission_amount >= 0
        AND professional_payable_amount >= 0
        AND customer_fee_amount >= 0
        AND provider_fee_amount >= 0
        AND tax_amount >= 0
    )
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_job
ON public.payment_allocations(job_id);


-- ============================================================
-- 5. RLS
-- ============================================================

ALTER TABLE public.payments
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment_evidence
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment_reconciliation
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment_allocations
ENABLE ROW LEVEL SECURITY;


-- Customer reads own payment
DROP POLICY IF EXISTS payments_select_customer_own
ON public.payments;

CREATE POLICY payments_select_customer_own
ON public.payments
FOR SELECT
TO authenticated
USING (
    customer_id = (SELECT auth.uid())
);


-- Professional reads payment status for assigned earnings only
DROP POLICY IF EXISTS payments_select_professional_own
ON public.payments;

CREATE POLICY payments_select_professional_own
ON public.payments
FOR SELECT
TO authenticated
USING (
    professional_id = (SELECT auth.uid())
);


-- Customer sees own evidence
DROP POLICY IF EXISTS payment_evidence_select_customer_own
ON public.payment_evidence;

CREATE POLICY payment_evidence_select_customer_own
ON public.payment_evidence
FOR SELECT
TO authenticated
USING (
    customer_id = (SELECT auth.uid())
);


-- Customer/professional may read resulting allocation
DROP POLICY IF EXISTS payment_allocations_select_parties
ON public.payment_allocations;

CREATE POLICY payment_allocations_select_parties
ON public.payment_allocations
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.payments p
        WHERE p.id = payment_allocations.payment_id
          AND (
              p.customer_id = (SELECT auth.uid())
              OR p.professional_id = (SELECT auth.uid())
          )
    )
);


-- No client-side access to reconciliation audit.
-- service_role/postgres bypass RLS as appropriate.


-- ============================================================
-- 6. TABLE PRIVILEGES
-- ============================================================
-- App reads through RLS.
-- All mutations happen through RPCs.
-- ============================================================

REVOKE ALL ON TABLE public.payments
FROM anon, authenticated;

REVOKE ALL ON TABLE public.payment_evidence
FROM anon, authenticated;

REVOKE ALL ON TABLE public.payment_reconciliation
FROM anon, authenticated;

REVOKE ALL ON TABLE public.payment_allocations
FROM anon, authenticated;

GRANT SELECT ON TABLE public.payments
TO authenticated;

GRANT SELECT ON TABLE public.payment_evidence
TO authenticated;

GRANT SELECT ON TABLE public.payment_allocations
TO authenticated;


-- ============================================================
-- 7. HELPER: UNIQUE PAYMENT REFERENCE
-- ============================================================

CREATE OR REPLACE FUNCTION public.generate_payment_reference()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ref text;
BEGIN
    LOOP
        v_ref :=
            'FIX-' ||
            to_char(timezone('utc', now()), 'YYMMDD') ||
            '-' ||
            upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

        EXIT WHEN NOT EXISTS (
            SELECT 1
            FROM public.payments
            WHERE reference_code = v_ref
        );
    END LOOP;

    RETURN v_ref;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.generate_payment_reference()
FROM PUBLIC, anon, authenticated;


-- ============================================================
-- 8. CUSTOMER RPC: PREPARE PAYMENT
-- ============================================================
-- This is the customer's "Aprobar y pagar" entry point.
-- Job remains work_completed until real payment confirmation.
-- ============================================================

CREATE OR REPLACE FUNCTION public.prepare_job_payment(
    p_job_id uuid,
    p_payment_method text
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_job public.jobs;
    v_snapshot public.job_financial_snapshots;
    v_payment public.payments;
    v_initial_status text;
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

    IF v_profile.role <> 'customer' THEN
        RAISE EXCEPTION 'NOT_A_CUSTOMER';
    END IF;

    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    IF p_payment_method NOT IN ('bank_transfer', 'card') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD';
    END IF;

    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = p_job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;

    IF v_job.client_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_OWNED_BY_CUSTOMER';
    END IF;

    -- Idempotency: existing payment wins.
    SELECT *
    INTO v_payment
    FROM public.payments
    WHERE job_id = p_job_id;

    IF FOUND THEN
        RETURN v_payment;
    END IF;

    IF v_job.status <> 'work_completed' THEN
        RAISE EXCEPTION 'JOB_NOT_READY_FOR_PAYMENT';
    END IF;

    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;

    SELECT *
    INTO v_snapshot
    FROM public.job_financial_snapshots
    WHERE job_id = p_job_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;

    IF v_snapshot.professional_id IS DISTINCT FROM v_job.assigned_pro_id THEN
        RAISE EXCEPTION 'SNAPSHOT_PROFESSIONAL_MISMATCH';
    END IF;

    IF p_payment_method = 'bank_transfer' THEN
        v_initial_status := 'pending_transfer';
    ELSE
        -- Card modeled but provider integration is not active in 018.
        v_initial_status := 'unpaid';
    END IF;

    INSERT INTO public.payments (
        job_id,
        customer_id,
        professional_id,
        snapshot_id,
        payment_method,
        status,
        currency,
        service_amount,
        customer_fee_amount,
        total_due,
        amount_received,
        reference_code,
        provider
    )
    VALUES (
        v_job.id,
        v_user_id,
        v_snapshot.professional_id,
        v_snapshot.id,
        p_payment_method,
        v_initial_status,
        'USD',
        v_snapshot.gross_amount,
        0,
        v_snapshot.gross_amount,
        0,
        public.generate_payment_reference(),
        CASE
            WHEN p_payment_method = 'bank_transfer' THEN 'manual_bank_transfer'
            ELSE NULL
        END
    )
    RETURNING *
    INTO v_payment;

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.prepare_job_payment(uuid, text)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.prepare_job_payment(uuid, text)
TO authenticated;


-- ============================================================
-- 9. CUSTOMER RPC: SUBMIT BANK TRANSFER EVIDENCE
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_bank_transfer_evidence(
    p_payment_id uuid,
    p_storage_path text,
    p_declared_amount numeric DEFAULT NULL,
    p_declared_bank text DEFAULT NULL,
    p_declared_reference text DEFAULT NULL
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_payment public.payments;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    IF p_storage_path IS NULL OR length(trim(p_storage_path)) = 0 THEN
        RAISE EXCEPTION 'EVIDENCE_STORAGE_PATH_REQUIRED';
    END IF;

    SELECT *
    INTO v_payment
    FROM public.payments
    WHERE id = p_payment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYMENT_NOT_FOUND';
    END IF;

    IF v_payment.customer_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'PAYMENT_NOT_OWNED_BY_CUSTOMER';
    END IF;

    IF v_payment.payment_method <> 'bank_transfer' THEN
        RAISE EXCEPTION 'PAYMENT_METHOD_NOT_BANK_TRANSFER';
    END IF;

    IF v_payment.status = 'paid' THEN
        RETURN v_payment;
    END IF;

    IF v_payment.status NOT IN (
        'pending_transfer',
        'voucher_uploaded',
        'pending_verification',
        'rejected'
    ) THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_STATE';
    END IF;

    INSERT INTO public.payment_evidence (
        payment_id,
        customer_id,
        storage_path,
        declared_amount,
        declared_bank,
        declared_reference
    )
    VALUES (
        v_payment.id,
        v_user_id,
        trim(p_storage_path),
        p_declared_amount,
        NULLIF(trim(p_declared_bank), ''),
        NULLIF(trim(p_declared_reference), '')
    );

    UPDATE public.payments
    SET
        status = 'pending_verification',
        rejected_at = NULL,
        rejection_reason = NULL,
        updated_at = timezone('utc', now())
    WHERE id = v_payment.id
    RETURNING *
    INTO v_payment;

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.submit_bank_transfer_evidence(
    uuid, text, numeric, text, text
)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.submit_bank_transfer_evidence(
    uuid, text, numeric, text, text
)
TO authenticated;


-- ============================================================
-- 10. TRUSTED RPC: VERIFY BANK TRANSFER
-- ============================================================
-- Only trusted backend/service role may confirm actual funds.
-- A voucher can NEVER execute this RPC from Flutter.
-- ============================================================

CREATE OR REPLACE FUNCTION public.verify_bank_transfer_trusted(
    p_payment_id uuid,
    p_amount_confirmed numeric,
    p_bank_reference text DEFAULT NULL,
    p_bank_transaction_id text DEFAULT NULL,
    p_verified_by uuid DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_payment public.payments;
    v_snapshot public.job_financial_snapshots;
    v_job public.jobs;
BEGIN
    SELECT *
    INTO v_payment
    FROM public.payments
    WHERE id = p_payment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYMENT_NOT_FOUND';
    END IF;

    IF v_payment.status = 'paid' THEN
        RETURN v_payment;
    END IF;

    IF v_payment.payment_method <> 'bank_transfer' THEN
        RAISE EXCEPTION 'PAYMENT_METHOD_NOT_BANK_TRANSFER';
    END IF;

    IF v_payment.status NOT IN (
        'pending_verification',
        'voucher_uploaded',
        'pending_transfer',
        'rejected'
    ) THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_STATE';
    END IF;

    IF p_amount_confirmed IS NULL OR p_amount_confirmed <= 0 THEN
        RAISE EXCEPTION 'INVALID_CONFIRMED_AMOUNT';
    END IF;

    -- MVP rule: exact total required.
    IF round(p_amount_confirmed, 2) <> round(v_payment.total_due, 2) THEN
        RAISE EXCEPTION 'PAYMENT_AMOUNT_MISMATCH';
    END IF;

    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = v_payment.job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;

    IF v_job.status <> 'work_completed' THEN
        RAISE EXCEPTION 'JOB_NOT_READY_FOR_FINANCIAL_APPROVAL';
    END IF;

    SELECT *
    INTO v_snapshot
    FROM public.job_financial_snapshots
    WHERE id = v_payment.snapshot_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;

    INSERT INTO public.payment_reconciliation (
        payment_id,
        result,
        amount_confirmed,
        bank_reference,
        bank_transaction_id,
        notes,
        verified_by
    )
    VALUES (
        v_payment.id,
        'confirmed',
        p_amount_confirmed,
        NULLIF(trim(p_bank_reference), ''),
        NULLIF(trim(p_bank_transaction_id), ''),
        NULLIF(trim(p_notes), ''),
        p_verified_by
    );

    INSERT INTO public.payment_allocations (
        payment_id,
        job_id,
        snapshot_id,
        service_gross_amount,
        platform_commission_amount,
        professional_payable_amount,
        customer_fee_amount,
        provider_fee_amount,
        tax_amount,
        tax_metadata,
        currency
    )
    VALUES (
        v_payment.id,
        v_payment.job_id,
        v_payment.snapshot_id,
        v_snapshot.gross_amount,
        v_snapshot.commission_amount,
        v_snapshot.professional_amount,
        v_payment.customer_fee_amount,
        0,
        0,
        '{}'::jsonb,
        'USD'
    )
    ON CONFLICT (payment_id)
    DO NOTHING;

    UPDATE public.payments
    SET
        status = 'paid',
        amount_received = p_amount_confirmed,
        provider_transaction_id =
            COALESCE(
                NULLIF(trim(p_bank_transaction_id), ''),
                provider_transaction_id
            ),
        paid_at = COALESCE(paid_at, timezone('utc', now())),
        verified_at = COALESCE(verified_at, timezone('utc', now())),
        verified_by = COALESCE(p_verified_by, verified_by),
        rejected_at = NULL,
        rejection_reason = NULL,
        updated_at = timezone('utc', now())
    WHERE id = v_payment.id
    RETURNING *
    INTO v_payment;

    -- Existing trusted economic engine:
    -- creates ledger entries + transitions work_completed -> customer_approved.
    PERFORM public.approve_completed_job_trusted(v_payment.job_id);

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.verify_bank_transfer_trusted(
    uuid, numeric, text, text, uuid, text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.verify_bank_transfer_trusted(
    uuid, numeric, text, text, uuid, text
)
TO service_role;


-- ============================================================
-- 11. TRUSTED RPC: REJECT BANK TRANSFER
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_bank_transfer_trusted(
    p_payment_id uuid,
    p_reason text,
    p_verified_by uuid DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_payment public.payments;
BEGIN
    IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
        RAISE EXCEPTION 'REJECTION_REASON_REQUIRED';
    END IF;

    SELECT *
    INTO v_payment
    FROM public.payments
    WHERE id = p_payment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAYMENT_NOT_FOUND';
    END IF;

    IF v_payment.status = 'paid' THEN
        RAISE EXCEPTION 'PAID_PAYMENT_CANNOT_BE_REJECTED';
    END IF;

    INSERT INTO public.payment_reconciliation (
        payment_id,
        result,
        amount_confirmed,
        notes,
        verified_by
    )
    VALUES (
        v_payment.id,
        'rejected',
        NULL,
        trim(p_reason) ||
            CASE
                WHEN p_notes IS NULL OR length(trim(p_notes)) = 0
                    THEN ''
                ELSE ' | ' || trim(p_notes)
            END,
        p_verified_by
    );

    UPDATE public.payments
    SET
        status = 'rejected',
        rejected_at = timezone('utc', now()),
        rejection_reason = trim(p_reason),
        updated_at = timezone('utc', now())
    WHERE id = v_payment.id
    RETURNING *
    INTO v_payment;

    RETURN v_payment;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.reject_bank_transfer_trusted(
    uuid, text, uuid, text
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.reject_bank_transfer_trusted(
    uuid, text, uuid, text
)
TO service_role;


-- ============================================================
-- 12. CLOSE LEGACY PAYMENT BYPASS
-- ============================================================
-- Prior versions allowed the authenticated customer to call
-- approve_completed_job() directly after work_completed.
-- From v1.9.0 this would bypass payment, so it is disabled.
-- The trusted function remains service-role only.
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.approve_completed_job(uuid)
FROM authenticated, anon, PUBLIC;

REVOKE EXECUTE
ON FUNCTION public.approve_completed_job_trusted(uuid)
FROM authenticated, anon, PUBLIC;

GRANT EXECUTE
ON FUNCTION public.approve_completed_job_trusted(uuid)
TO service_role;


COMMIT;
