BEGIN;

-- ============================================================
-- FIXIS PRO v1.4.0
-- MIGRATION 009
-- FINANCIAL LEDGER FOUNDATION
-- ============================================================


-- ============================================================
-- 1. AMPLIAR STATE MACHINE DE JOBS
-- ============================================================

ALTER TABLE public.jobs
DROP CONSTRAINT IF EXISTS jobs_status_check;

ALTER TABLE public.jobs
ADD CONSTRAINT jobs_status_check
CHECK (
    status IN (
        'pending',
        'accepted',
        'quote_submitted',
        'authorized',
        'in_progress',
        'work_completed',
        'customer_approved',

        -- Legacy / compatibilidad temporal
        'completed',

        'cancelled'
    )
);


-- ============================================================
-- 2. RETIRAR TRIGGER LEGACY
--
-- Ya no queremos que "completed" gobierne gamificación
-- ni finanzas.
-- ============================================================

DROP TRIGGER IF EXISTS tr_job_completed
ON public.jobs;


-- La función se conserva temporalmente como legacy,
-- pero nadie desde Flutter puede ejecutarla.

REVOKE EXECUTE
ON FUNCTION public.handle_completed_job()
FROM PUBLIC, anon, authenticated;



-- ============================================================
-- 3. FINANCIAL ACCOUNTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.financial_accounts (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    account_code text NOT NULL UNIQUE,

    account_type text NOT NULL,

    professional_id uuid,

    currency text NOT NULL DEFAULT 'USD',

    active boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT financial_accounts_type_check
    CHECK (
        account_type IN (
            'professional_payable',
            'platform_revenue'
        )
    ),


    CONSTRAINT financial_accounts_currency_check
    CHECK (
        currency = 'USD'
    ),


    CONSTRAINT financial_accounts_owner_check
    CHECK (

        (
            account_type = 'professional_payable'
            AND professional_id IS NOT NULL
        )

        OR

        (
            account_type = 'platform_revenue'
            AND professional_id IS NULL
        )

    ),


    CONSTRAINT financial_accounts_professional_fk
    FOREIGN KEY (professional_id)
    REFERENCES public.profiles(id)
    ON DELETE RESTRICT
);


-- Solo una cuenta payable por profesional

CREATE UNIQUE INDEX IF NOT EXISTS
idx_financial_accounts_professional_payable
ON public.financial_accounts(professional_id)
WHERE account_type = 'professional_payable';


-- Cuenta interna FIXIS

INSERT INTO public.financial_accounts (
    account_code,
    account_type,
    professional_id,
    currency,
    active
)
VALUES (
    'FIXIS_REVENUE_USD',
    'platform_revenue',
    NULL,
    'USD',
    true
)
ON CONFLICT (account_code)
DO UPDATE SET
    active = true;



-- ============================================================
-- 4. LEDGER APPEND-ONLY
-- ============================================================

CREATE TABLE IF NOT EXISTS public.financial_ledger_entries (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    account_id uuid NOT NULL,

    job_id uuid NOT NULL,

    snapshot_id uuid NOT NULL,

    entry_type text NOT NULL,

    direction text NOT NULL,

    amount numeric(12,2) NOT NULL,

    currency text NOT NULL DEFAULT 'USD',

    status text NOT NULL,

    description text NOT NULL,

    idempotency_key text NOT NULL UNIQUE,

    created_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    available_at timestamptz,

    settled_at timestamptz,


    CONSTRAINT ledger_account_fk
    FOREIGN KEY (account_id)
    REFERENCES public.financial_accounts(id)
    ON DELETE RESTRICT,


    CONSTRAINT ledger_job_fk
    FOREIGN KEY (job_id)
    REFERENCES public.jobs(id)
    ON DELETE RESTRICT,


    CONSTRAINT ledger_snapshot_fk
    FOREIGN KEY (snapshot_id)
    REFERENCES public.job_financial_snapshots(id)
    ON DELETE RESTRICT,


    CONSTRAINT ledger_entry_type_check
    CHECK (
        entry_type IN (
            'professional_earning',
            'platform_commission',
            'settlement_debit',
            'reversal'
        )
    ),


    CONSTRAINT ledger_direction_check
    CHECK (
        direction IN (
            'credit',
            'debit'
        )
    ),


    CONSTRAINT ledger_status_check
    CHECK (
        status IN (
            'pending',
            'available',
            'settled',
            'reversed'
        )
    ),


    CONSTRAINT ledger_amount_check
    CHECK (
        amount > 0
    ),


    CONSTRAINT ledger_currency_check
    CHECK (
        currency = 'USD'
    )
);



-- ============================================================
-- 5. ÍNDICES DEL LEDGER
-- ============================================================

CREATE INDEX IF NOT EXISTS
idx_ledger_account_created
ON public.financial_ledger_entries(
    account_id,
    created_at DESC
);


CREATE INDEX IF NOT EXISTS
idx_ledger_job
ON public.financial_ledger_entries(job_id);


CREATE INDEX IF NOT EXISTS
idx_ledger_snapshot
ON public.financial_ledger_entries(snapshot_id);


CREATE INDEX IF NOT EXISTS
idx_ledger_status
ON public.financial_ledger_entries(status);



-- ============================================================
-- 6. RLS
-- ============================================================

ALTER TABLE public.financial_accounts
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.financial_ledger_entries
ENABLE ROW LEVEL SECURITY;



-- ============================================================
-- 7. PROFESSIONAL: VER SU PROPIA CUENTA
-- ============================================================

DROP POLICY IF EXISTS
"financial_accounts_select_own"
ON public.financial_accounts;


CREATE POLICY "financial_accounts_select_own"
ON public.financial_accounts
FOR SELECT
TO authenticated
USING (
    professional_id = (
        SELECT auth.uid()
    )
);



-- ============================================================
-- 8. PROFESSIONAL: VER SU PROPIO LEDGER
-- ============================================================

DROP POLICY IF EXISTS
"financial_ledger_select_own"
ON public.financial_ledger_entries;


CREATE POLICY "financial_ledger_select_own"
ON public.financial_ledger_entries
FOR SELECT
TO authenticated
USING (

    EXISTS (

        SELECT 1
        FROM public.financial_accounts fa

        WHERE fa.id =
            financial_ledger_entries.account_id

          AND fa.professional_id = (
              SELECT auth.uid()
          )

    )

);



-- ============================================================
-- 9. GRANTS
--
-- Flutter:
-- SELECT propio ✅
-- INSERT/UPDATE/DELETE ❌
-- ============================================================

REVOKE ALL
ON public.financial_accounts
FROM anon;

REVOKE INSERT, UPDATE, DELETE,
       TRUNCATE, REFERENCES, TRIGGER
ON public.financial_accounts
FROM authenticated;

GRANT SELECT
ON public.financial_accounts
TO authenticated;



REVOKE ALL
ON public.financial_ledger_entries
FROM anon;

REVOKE INSERT, UPDATE, DELETE,
       TRUNCATE, REFERENCES, TRIGGER
ON public.financial_ledger_entries
FROM authenticated;

GRANT SELECT
ON public.financial_ledger_entries
TO authenticated;



-- ============================================================
-- 10. finish_job()
--
-- FIXI declara que terminó.
--
-- NO genera dinero.
-- NO incrementa gamificación.
-- ============================================================

CREATE OR REPLACE FUNCTION public.finish_job(
    p_job_id uuid
)
RETURNS public.jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;
    v_profile public.profiles;
    v_job public.jobs;

BEGIN

    v_user_id := auth.uid();


    -- --------------------------------------------------------
    -- AUTH
    -- --------------------------------------------------------

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
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
    -- LOCK JOB
    -- --------------------------------------------------------

    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = p_job_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.assigned_pro_id
       IS DISTINCT FROM v_user_id
    THEN

        RAISE EXCEPTION
        'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';

    END IF;


    -- Idempotencia ligera:
    -- si ya fue declarado terminado,
    -- devolvemos el job.

    IF v_job.status = 'work_completed' THEN
        RETURN v_job;
    END IF;


    IF v_job.status <> 'in_progress' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;


    -- Debe existir snapshot económico

    IF NOT EXISTS (

        SELECT 1

        FROM public.job_financial_snapshots fs

        WHERE fs.job_id = v_job.id

          AND fs.quote_id =
              v_job.accepted_quote_id

    ) THEN

        RAISE EXCEPTION
        'FINANCIAL_SNAPSHOT_REQUIRED';

    END IF;


    -- --------------------------------------------------------
    -- FINALIZACIÓN TÉCNICA
    -- --------------------------------------------------------

    UPDATE public.jobs

    SET status = 'work_completed'

    WHERE id = p_job_id

    RETURNING *
    INTO v_job;


    RETURN v_job;

END;
$$;



REVOKE EXECUTE
ON FUNCTION public.finish_job(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.finish_job(uuid)
TO authenticated;



-- ============================================================
-- 11. CUSTOMER APPROVAL TRUSTED
--
-- Temporal:
-- mientras jobs no tenga client_id,
-- solo backend/admin confiable puede ejecutarla.
--
-- Esta función:
--   - customer_approved
--   - crea cuentas
--   - genera ledger
--   - actualiza gamificación
--   - incrementa total_jobs
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_completed_job_trusted(
    p_job_id uuid
)
RETURNS public.jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_job public.jobs;

    v_snapshot public.job_financial_snapshots;

    v_prof_account public.financial_accounts;

    v_fixis_account public.financial_accounts;

BEGIN

    -- --------------------------------------------------------
    -- LOCK JOB
    -- --------------------------------------------------------

    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = p_job_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- IDEMPOTENCIA
    --
    -- Ya aprobado = no hacemos nada de nuevo.
    -- --------------------------------------------------------

    IF v_job.status = 'customer_approved' THEN

        RETURN v_job;

    END IF;


    IF v_job.status <> 'work_completed' THEN

        RAISE EXCEPTION 'INVALID_JOB_STATE';

    END IF;


    IF v_job.assigned_pro_id IS NULL THEN

        RAISE EXCEPTION
        'PROFESSIONAL_REQUIRED';

    END IF;


    IF v_job.accepted_quote_id IS NULL THEN

        RAISE EXCEPTION
        'ACCEPTED_QUOTE_REQUIRED';

    END IF;


    -- --------------------------------------------------------
    -- SNAPSHOT
    -- --------------------------------------------------------

    SELECT *
    INTO v_snapshot

    FROM public.job_financial_snapshots

    WHERE job_id = v_job.id

      AND quote_id =
          v_job.accepted_quote_id

    FOR UPDATE;


    IF NOT FOUND THEN

        RAISE EXCEPTION
        'FINANCIAL_SNAPSHOT_REQUIRED';

    END IF;


    IF v_snapshot.professional_id
       IS DISTINCT FROM v_job.assigned_pro_id
    THEN

        RAISE EXCEPTION
        'FINANCIAL_PROFESSIONAL_MISMATCH';

    END IF;



    -- ========================================================
    -- PROFESSIONAL FINANCIAL ACCOUNT
    -- ========================================================

    INSERT INTO public.financial_accounts (

        account_code,

        account_type,

        professional_id,

        currency,

        active

    )

    VALUES (

        'PROFESSIONAL_PAYABLE:'
        || v_snapshot.professional_id::text,

        'professional_payable',

        v_snapshot.professional_id,

        'USD',

        true

    )

    ON CONFLICT (account_code)

    DO UPDATE SET
        active = true

    RETURNING *
    INTO v_prof_account;



    -- ========================================================
    -- FIXIS REVENUE ACCOUNT
    -- ========================================================

    SELECT *
    INTO v_fixis_account

    FROM public.financial_accounts

    WHERE account_code =
        'FIXIS_REVENUE_USD';


    IF NOT FOUND THEN

        RAISE EXCEPTION
        'FIXIS_REVENUE_ACCOUNT_NOT_FOUND';

    END IF;



    -- ========================================================
    -- PROFESSIONAL EARNING
    --
    -- Unique idempotency_key impide doble generación.
    -- ========================================================

    IF v_snapshot.professional_amount > 0 THEN

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

            available_at

        )

        VALUES (

            v_prof_account.id,

            v_job.id,

            v_snapshot.id,

            'professional_earning',

            'credit',

            v_snapshot.professional_amount,

            'USD',

            'available',

            'Ingreso por servicio aprobado: '
                || v_job.title,

            'JOB:'
                || v_job.id::text
                || ':PROFESSIONAL_EARNING',

            now()

        )

        ON CONFLICT (idempotency_key)
        DO NOTHING;

    END IF;



    -- ========================================================
    -- FIXIS COMMISSION REVENUE
    -- ========================================================

    IF v_snapshot.commission_amount > 0 THEN

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

            available_at

        )

        VALUES (

            v_fixis_account.id,

            v_job.id,

            v_snapshot.id,

            'platform_commission',

            'credit',

            v_snapshot.commission_amount,

            'USD',

            'available',

            'Comisión FIXIS: '
                || v_job.title,

            'JOB:'
                || v_job.id::text
                || ':PLATFORM_COMMISSION',

            now()

        )

        ON CONFLICT (idempotency_key)
        DO NOTHING;

    END IF;



    -- ========================================================
    -- JOB APPROVED
    -- ========================================================

    UPDATE public.jobs

    SET status = 'customer_approved'

    WHERE id = v_job.id

    RETURNING *
    INTO v_job;



    -- ========================================================
    -- PROFILE STATS
    -- ========================================================

    UPDATE public.profiles

    SET total_jobs =
        COALESCE(total_jobs, 0) + 1

    WHERE id =
        v_snapshot.professional_id;



    -- ========================================================
    -- GAMIFICATION
    --
    -- Solo cuenta trabajos aprobados.
    -- ========================================================

    INSERT INTO public.expert_gamification (

        pro_id,

        current_rank,

        completed_jobs_count,

        target_jobs_count,

        badges,

        updated_at

    )

    VALUES (

        v_snapshot.professional_id,

        'Inicial',

        1,

        5,

        '[]'::jsonb,

        now()

    )

    ON CONFLICT (pro_id)

    DO UPDATE SET

        completed_jobs_count =
            public.expert_gamification
                .completed_jobs_count + 1,

        updated_at = now();



    RETURN v_job;

END;
$$;



-- ============================================================
-- 12. TRUSTED = NO FLUTTER
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.approve_completed_job_trusted(uuid)
FROM PUBLIC, anon, authenticated;


COMMIT;