BEGIN;

-- ============================================================
-- FIXIS PRO v1.5.0
-- MIGRATION 010
-- WALLET V2 + SETTLEMENTS
-- ============================================================


-- ============================================================
-- 1. SETTLEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.settlements (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    professional_id uuid NOT NULL,

    account_id uuid NOT NULL,

    requested_amount numeric(12,2) NOT NULL,

    currency text NOT NULL DEFAULT 'USD',

    status text NOT NULL DEFAULT 'requested',

    -- Snapshot del destino bancario al momento del retiro
    bank_name text,
    bank_account_type text,
    bank_account_number text,

    requested_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    processing_at timestamptz,

    paid_at timestamptz,

    rejected_at timestamptz,

    cancelled_at timestamptz,

    rejection_reason text,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT settlements_professional_fk
    FOREIGN KEY (professional_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT,


    CONSTRAINT settlements_account_fk
    FOREIGN KEY (account_id)
    REFERENCES public.financial_accounts(id)
    ON DELETE RESTRICT,


    CONSTRAINT settlements_amount_check
    CHECK (requested_amount > 0),


    CONSTRAINT settlements_currency_check
    CHECK (currency = 'USD'),


    CONSTRAINT settlements_status_check
    CHECK (
        status IN (
            'requested',
            'processing',
            'paid',
            'rejected',
            'cancelled'
        )
    )
);


CREATE INDEX IF NOT EXISTS
idx_settlements_professional_created
ON public.settlements(
    professional_id,
    created_at DESC
);


CREATE INDEX IF NOT EXISTS
idx_settlements_status
ON public.settlements(status);



-- ============================================================
-- 2. SETTLEMENT ITEMS
--
-- Indican qué earnings financiaron cada retiro.
-- Permiten retiros parciales.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.settlement_items (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    settlement_id uuid NOT NULL,

    ledger_entry_id uuid NOT NULL,

    allocated_amount numeric(12,2) NOT NULL,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT settlement_items_settlement_fk
    FOREIGN KEY (settlement_id)
    REFERENCES public.settlements(id)
    ON DELETE RESTRICT,


    CONSTRAINT settlement_items_ledger_fk
    FOREIGN KEY (ledger_entry_id)
    REFERENCES public.financial_ledger_entries(id)
    ON DELETE RESTRICT,


    CONSTRAINT settlement_items_amount_check
    CHECK (allocated_amount > 0),


    CONSTRAINT settlement_items_unique_source
    UNIQUE (
        settlement_id,
        ledger_entry_id
    )
);


CREATE INDEX IF NOT EXISTS
idx_settlement_items_settlement
ON public.settlement_items(settlement_id);


CREATE INDEX IF NOT EXISTS
idx_settlement_items_ledger
ON public.settlement_items(ledger_entry_id);



-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE public.settlements
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.settlement_items
ENABLE ROW LEVEL SECURITY;



-- ------------------------------------------------------------
-- Profesional ve sus retiros
-- ------------------------------------------------------------

DROP POLICY IF EXISTS
"settlements_select_own"
ON public.settlements;


CREATE POLICY "settlements_select_own"
ON public.settlements
FOR SELECT
TO authenticated
USING (
    professional_id = (
        SELECT auth.uid()
    )
);



-- ------------------------------------------------------------
-- Profesional ve los items de sus retiros
-- ------------------------------------------------------------

DROP POLICY IF EXISTS
"settlement_items_select_own"
ON public.settlement_items;


CREATE POLICY "settlement_items_select_own"
ON public.settlement_items
FOR SELECT
TO authenticated
USING (

    EXISTS (

        SELECT 1

        FROM public.settlements s

        WHERE s.id =
            settlement_items.settlement_id

          AND s.professional_id = (
              SELECT auth.uid()
          )

    )

);



-- ============================================================
-- 4. GRANTS
-- ============================================================

REVOKE ALL
ON public.settlements
FROM anon;

REVOKE INSERT, UPDATE, DELETE,
       TRUNCATE, REFERENCES, TRIGGER
ON public.settlements
FROM authenticated;

GRANT SELECT
ON public.settlements
TO authenticated;



REVOKE ALL
ON public.settlement_items
FROM anon;

REVOKE INSERT, UPDATE, DELETE,
       TRUNCATE, REFERENCES, TRIGGER
ON public.settlement_items
FROM authenticated;

GRANT SELECT
ON public.settlement_items
TO authenticated;



-- ============================================================
-- 5. WALLET SUMMARY RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_wallet_summary()
RETURNS TABLE (

    available_balance numeric,

    reserved_balance numeric,

    total_earned numeric,

    total_withdrawn numeric,

    currency text

)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;

    v_account_id uuid;

    v_total_earned numeric(12,2) := 0;

    v_reserved numeric(12,2) := 0;

    v_withdrawn numeric(12,2) := 0;

BEGIN

    v_user_id := auth.uid();


    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    SELECT id
    INTO v_account_id

    FROM public.financial_accounts

    WHERE professional_id = v_user_id

      AND account_type =
          'professional_payable'

      AND active = true;


    -- Profesional aún sin earnings
    IF NOT FOUND THEN

        RETURN QUERY
        SELECT
            0::numeric,
            0::numeric,
            0::numeric,
            0::numeric,
            'USD'::text;

        RETURN;

    END IF;


    -- --------------------------------------------------------
    -- TOTAL GANADO HISTÓRICO
    -- --------------------------------------------------------

    SELECT COALESCE(SUM(le.amount), 0)

    INTO v_total_earned

    FROM public.financial_ledger_entries le

    WHERE le.account_id = v_account_id

      AND le.entry_type =
          'professional_earning'

      AND le.direction = 'credit'

      AND le.status IN (
          'available',
          'settled'
      );


    -- --------------------------------------------------------
    -- RESERVADO EN RETIROS ACTIVOS
    -- --------------------------------------------------------

    SELECT COALESCE(
        SUM(si.allocated_amount),
        0
    )

    INTO v_reserved

    FROM public.settlement_items si

    JOIN public.settlements s
      ON s.id = si.settlement_id

    WHERE s.account_id = v_account_id

      AND s.status IN (
          'requested',
          'processing'
      );


    -- --------------------------------------------------------
    -- TOTAL YA PAGADO
    -- --------------------------------------------------------

    SELECT COALESCE(SUM(le.amount), 0)

    INTO v_withdrawn

    FROM public.financial_ledger_entries le

    WHERE le.account_id = v_account_id

      AND le.entry_type =
          'settlement_debit'

      AND le.direction = 'debit'

      AND le.status = 'settled';


    RETURN QUERY

    SELECT

        GREATEST(
            v_total_earned
            - v_withdrawn
            - v_reserved,
            0
        )::numeric,

        v_reserved::numeric,

        v_total_earned::numeric,

        v_withdrawn::numeric,

        'USD'::text;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.get_wallet_summary()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.get_wallet_summary()
TO authenticated;



-- ============================================================
-- 6. REQUEST WITHDRAWAL
-- ============================================================

CREATE OR REPLACE FUNCTION public.request_withdrawal(
    p_amount numeric
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;

    v_profile public.profiles;

    v_account public.financial_accounts;

    v_settlement public.settlements;

    v_available numeric(12,2);

    v_remaining numeric(12,2);

    v_allocatable numeric(12,2);

    v_already_allocated numeric(12,2);

    v_entry record;

BEGIN

    v_user_id := auth.uid();


    -- --------------------------------------------------------
    -- AUTH
    -- --------------------------------------------------------

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_WITHDRAWAL_AMOUNT';
    END IF;


    -- --------------------------------------------------------
    -- PROFILE
    -- --------------------------------------------------------

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


    IF v_profile.verification_status <> 'approved' THEN
        RAISE EXCEPTION 'PROFESSIONAL_NOT_APPROVED';
    END IF;


    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;


    -- --------------------------------------------------------
    -- DATOS BANCARIOS
    -- --------------------------------------------------------

    IF COALESCE(TRIM(v_profile.bank), '') = ''
       OR COALESCE(TRIM(v_profile.account_type), '') = ''
       OR COALESCE(TRIM(v_profile.account_number), '') = ''
    THEN

        RAISE EXCEPTION 'PAYOUT_DETAILS_REQUIRED';

    END IF;


    -- --------------------------------------------------------
    -- ACCOUNT + LOCK
    --
    -- Serializa solicitudes concurrentes del mismo profesional.
    -- --------------------------------------------------------

    SELECT *
    INTO v_account

    FROM public.financial_accounts

    WHERE professional_id = v_user_id

      AND account_type =
          'professional_payable'

      AND active = true

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_ACCOUNT_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- AVAILABLE REAL
    --
    -- Earnings menos TODO lo ya asignado a settlements
    -- válidos (requested, processing o paid).
    -- --------------------------------------------------------

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

                      AND s.status IN (
                          'requested',
                          'processing',
                          'paid'
                      )
                ),
                0
            )

        ),

        0

    )

    INTO v_available

    FROM public.financial_ledger_entries le

    WHERE le.account_id = v_account.id

      AND le.entry_type =
          'professional_earning'

      AND le.direction = 'credit'

      AND le.status = 'available';


    IF p_amount > v_available THEN

        RAISE EXCEPTION
        'INSUFFICIENT_AVAILABLE_BALANCE';

    END IF;


    -- --------------------------------------------------------
    -- CREATE SETTLEMENT
    -- --------------------------------------------------------

    INSERT INTO public.settlements (

        professional_id,

        account_id,

        requested_amount,

        currency,

        status,

        bank_name,

        bank_account_type,

        bank_account_number

    )

    VALUES (

        v_user_id,

        v_account.id,

        ROUND(p_amount, 2),

        'USD',

        'requested',

        v_profile.bank,

        v_profile.account_type,

        v_profile.account_number

    )

    RETURNING *
    INTO v_settlement;


    -- --------------------------------------------------------
    -- ALLOCATION FIFO
    -- --------------------------------------------------------

    v_remaining := ROUND(p_amount, 2);


    FOR v_entry IN

        SELECT

            le.id,

            le.amount,

            le.created_at

        FROM public.financial_ledger_entries le

        WHERE le.account_id = v_account.id

          AND le.entry_type =
              'professional_earning'

          AND le.direction = 'credit'

          AND le.status = 'available'

        ORDER BY le.created_at, le.id

        FOR UPDATE

    LOOP

        SELECT COALESCE(
            SUM(si.allocated_amount),
            0
        )

        INTO v_already_allocated

        FROM public.settlement_items si

        JOIN public.settlements s
          ON s.id = si.settlement_id

        WHERE si.ledger_entry_id =
            v_entry.id

          AND s.status IN (
              'requested',
              'processing',
              'paid'
          );


        v_allocatable :=
            v_entry.amount
            - v_already_allocated;


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

            LEAST(
                v_remaining,
                v_allocatable
            )

        );


        v_remaining :=
            v_remaining
            -
            LEAST(
                v_remaining,
                v_allocatable
            );


        EXIT WHEN v_remaining <= 0;

    END LOOP;


    IF v_remaining > 0 THEN

        RAISE EXCEPTION
        'WITHDRAWAL_ALLOCATION_FAILED';

    END IF;


    RETURN v_settlement;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.request_withdrawal(numeric)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.request_withdrawal(numeric)
TO authenticated;



-- ============================================================
-- 7. CANCEL WITHDRAWAL
--
-- Profesional puede cancelar solo mientras esté requested.
-- Los settlement_items quedan como auditoría,
-- pero dejan de reservar saldo porque settlement=cancelled.
-- ============================================================

CREATE OR REPLACE FUNCTION public.cancel_withdrawal(
    p_settlement_id uuid
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;

    v_settlement public.settlements;

BEGIN

    v_user_id := auth.uid();


    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    SELECT *
    INTO v_settlement

    FROM public.settlements

    WHERE id = p_settlement_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;


    IF v_settlement.professional_id
       IS DISTINCT FROM v_user_id
    THEN

        RAISE EXCEPTION
        'SETTLEMENT_NOT_OWNED';

    END IF;


    IF v_settlement.status = 'cancelled' THEN
        RETURN v_settlement;
    END IF;


    IF v_settlement.status <> 'requested' THEN
        RAISE EXCEPTION
        'SETTLEMENT_CANNOT_BE_CANCELLED';
    END IF;


    UPDATE public.settlements

    SET
        status = 'cancelled',
        cancelled_at = now()

    WHERE id = p_settlement_id

    RETURNING *
    INTO v_settlement;


    RETURN v_settlement;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.cancel_withdrawal(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.cancel_withdrawal(uuid)
TO authenticated;



-- ============================================================
-- 8. TRUSTED: MARK PROCESSING
-- ============================================================

CREATE OR REPLACE FUNCTION public.mark_settlement_processing_trusted(
    p_settlement_id uuid
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_settlement public.settlements;

BEGIN

    SELECT *
    INTO v_settlement

    FROM public.settlements

    WHERE id = p_settlement_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;


    IF v_settlement.status = 'processing' THEN
        RETURN v_settlement;
    END IF;


    IF v_settlement.status <> 'requested' THEN
        RAISE EXCEPTION 'INVALID_SETTLEMENT_STATE';
    END IF;


    UPDATE public.settlements

    SET
        status = 'processing',
        processing_at = now()

    WHERE id = p_settlement_id

    RETURNING *
    INTO v_settlement;


    RETURN v_settlement;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.mark_settlement_processing_trusted(uuid)
FROM PUBLIC, anon, authenticated;



-- ============================================================
-- 9. TRUSTED: MARK PAID
--
-- Genera el debit definitivo del ledger.
-- ============================================================

CREATE OR REPLACE FUNCTION public.mark_settlement_paid_trusted(
    p_settlement_id uuid
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_settlement public.settlements;

BEGIN

    SELECT *
    INTO v_settlement

    FROM public.settlements

    WHERE id = p_settlement_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;


    -- Idempotente
    IF v_settlement.status = 'paid' THEN
        RETURN v_settlement;
    END IF;


    IF v_settlement.status NOT IN (
        'requested',
        'processing'
    ) THEN

        RAISE EXCEPTION 'INVALID_SETTLEMENT_STATE';

    END IF;


    -- --------------------------------------------------------
    -- LEDGER DEBIT
    -- --------------------------------------------------------

    INSERT INTO public.financial_ledger_entries (

        account_id,

        job_id,

        snapshot_id,

        entry_type,

        direction,

        amount,

        currency,

        status,

        description,

        idempotency_key,

        available_at,

        settled_at

    )

    SELECT

        v_settlement.account_id,

        source.job_id,

        source.snapshot_id,

        'settlement_debit',

        'debit',

        v_settlement.requested_amount,

        'USD',

        'settled',

        'Retiro pagado FIXIS',

        'SETTLEMENT:'
            || v_settlement.id::text
            || ':DEBIT',

        now(),

        now()

    FROM (

        SELECT
            le.job_id,
            le.snapshot_id

        FROM public.settlement_items si

        JOIN public.financial_ledger_entries le
          ON le.id = si.ledger_entry_id

        WHERE si.settlement_id =
            v_settlement.id

        ORDER BY si.created_at

        LIMIT 1

    ) source

    ON CONFLICT (idempotency_key)
    DO NOTHING;


    UPDATE public.settlements

    SET
        status = 'paid',
        paid_at = now()

    WHERE id = p_settlement_id

    RETURNING *
    INTO v_settlement;


    RETURN v_settlement;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.mark_settlement_paid_trusted(uuid)
FROM PUBLIC, anon, authenticated;



-- ============================================================
-- 10. TRUSTED: REJECT
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_settlement_trusted(
    p_settlement_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS public.settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_settlement public.settlements;

BEGIN

    SELECT *
    INTO v_settlement

    FROM public.settlements

    WHERE id = p_settlement_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'SETTLEMENT_NOT_FOUND';
    END IF;


    IF v_settlement.status = 'rejected' THEN
        RETURN v_settlement;
    END IF;


    IF v_settlement.status NOT IN (
        'requested',
        'processing'
    ) THEN

        RAISE EXCEPTION 'INVALID_SETTLEMENT_STATE';

    END IF;


    UPDATE public.settlements

    SET
        status = 'rejected',
        rejected_at = now(),
        rejection_reason = p_reason

    WHERE id = p_settlement_id

    RETURNING *
    INTO v_settlement;


    RETURN v_settlement;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.reject_settlement_trusted(uuid, text)
FROM PUBLIC, anon, authenticated;


COMMIT;