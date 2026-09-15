BEGIN;

-- ============================================================
-- FIXIS PRO v1.6.0
-- MIGRATION 012
-- CLIENT IDENTITY + SECURE APPROVAL FLOW
-- ============================================================


-- ============================================================
-- 1. CLIENT ID EN JOBS
-- ============================================================

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS client_id uuid;


-- ------------------------------------------------------------
-- Eliminar FK redundante assigned_pro_id -> auth.users
-- Conservamos assigned_pro_id -> profiles.id
-- ------------------------------------------------------------

ALTER TABLE public.jobs
DROP CONSTRAINT IF EXISTS jobs_assigned_pro_id_fkey;


-- ------------------------------------------------------------
-- FK client_id -> profiles.id
-- ------------------------------------------------------------

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.jobs'::regclass
          AND conname = 'jobs_client_fk'
    ) THEN

        ALTER TABLE public.jobs
        ADD CONSTRAINT jobs_client_fk
        FOREIGN KEY (client_id)
        REFERENCES public.profiles(id)
        ON DELETE SET NULL;

    END IF;

END;
$$;


CREATE INDEX IF NOT EXISTS idx_jobs_client_id
ON public.jobs(client_id);



-- ============================================================
-- 2. RLS JOBS
--
-- Antes:
-- cualquier authenticated podía ver todos los pending.
--
-- Ahora:
-- professional ve oportunidades/servicios propios.
-- customer ve exclusivamente jobs propios.
-- ============================================================

DROP POLICY IF EXISTS
jobs_select_for_professional
ON public.jobs;


CREATE POLICY jobs_select_for_professional
ON public.jobs
FOR SELECT
TO authenticated
USING (

    EXISTS (

        SELECT 1

        FROM public.profiles p

        WHERE p.id = (
            SELECT auth.uid()
        )

          AND p.role = 'professional'

          AND p.verification_status = 'approved'

          AND p.account_status = 'active'

    )

    AND (

        status = 'pending'

        OR assigned_pro_id = (
            SELECT auth.uid()
        )

    )

);


DROP POLICY IF EXISTS
jobs_select_for_customer
ON public.jobs;


CREATE POLICY jobs_select_for_customer
ON public.jobs
FOR SELECT
TO authenticated
USING (

    client_id = (
        SELECT auth.uid()
    )

    AND EXISTS (

        SELECT 1

        FROM public.profiles p

        WHERE p.id = (
            SELECT auth.uid()
        )

          AND p.role = 'customer'

          AND p.account_status = 'active'

    )

);



-- ============================================================
-- 3. RLS QUOTES
--
-- Profesional:
-- ve sus propias cotizaciones.
--
-- Cliente:
-- ve cotizaciones ya enviadas relacionadas
-- con SUS trabajos.
-- ============================================================

DROP POLICY IF EXISTS
quotes_select_own
ON public.quotes;


CREATE POLICY quotes_select_own
ON public.quotes
FOR SELECT
TO authenticated
USING (

    professional_id = (
        SELECT auth.uid()
    )

    AND EXISTS (

        SELECT 1

        FROM public.profiles p

        WHERE p.id = (
            SELECT auth.uid()
        )

          AND p.role = 'professional'

          AND p.verification_status = 'approved'

          AND p.account_status = 'active'

    )

);


DROP POLICY IF EXISTS
quotes_select_for_customer
ON public.quotes;


CREATE POLICY quotes_select_for_customer
ON public.quotes
FOR SELECT
TO authenticated
USING (

    status IN (
        'submitted',
        'accepted',
        'rejected',
        'cancelled',
        'expired'
    )

    AND EXISTS (

        SELECT 1

        FROM public.jobs j

        WHERE j.id = quotes.job_id

          AND j.client_id = (
              SELECT auth.uid()
          )

    )

);



-- ============================================================
-- 4. CUSTOMER ACCEPT QUOTE
--
-- IMPORTANTE:
-- No duplicamos el motor financiero.
--
-- Esta función:
-- 1. autentica cliente
-- 2. verifica propiedad del job
-- 3. bloquea job + quote
-- 4. llama al motor trusted existente
--
-- accept_quote_trusted() sigue siendo el motor económico.
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_quote_customer(
    p_quote_id uuid
)
RETURNS public.jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;

    v_profile public.profiles;

    v_quote public.quotes;

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
    -- CUSTOMER PROFILE
    -- --------------------------------------------------------

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


    -- --------------------------------------------------------
    -- QUOTE LOCK
    -- --------------------------------------------------------

    SELECT *
    INTO v_quote

    FROM public.quotes

    WHERE id = p_quote_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- JOB LOCK
    -- --------------------------------------------------------

    SELECT *
    INTO v_job

    FROM public.jobs

    WHERE id = v_quote.job_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- OWNERSHIP
    -- --------------------------------------------------------

    IF v_job.client_id IS DISTINCT FROM v_user_id THEN

        RAISE EXCEPTION 'JOB_NOT_OWNED_BY_CUSTOMER';

    END IF;


    -- --------------------------------------------------------
    -- IDEMPOTENCIA
    -- --------------------------------------------------------

    IF v_job.status = 'authorized'
       AND v_job.accepted_quote_id = p_quote_id
    THEN

        RETURN v_job;

    END IF;


    IF v_job.accepted_quote_id IS NOT NULL
       AND v_job.accepted_quote_id <> p_quote_id
    THEN

        RAISE EXCEPTION 'ANOTHER_QUOTE_ALREADY_ACCEPTED';

    END IF;


    IF v_job.status <> 'quote_submitted' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_quote.status <> 'submitted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    -- --------------------------------------------------------
    -- MOTOR ECONÓMICO EXISTENTE
    --
    -- Calcula comisión + snapshot y autoriza job.
    -- --------------------------------------------------------

    PERFORM public.accept_quote_trusted(
        p_quote_id
    );


    SELECT *
    INTO v_job

    FROM public.jobs

    WHERE id = v_quote.job_id;


    RETURN v_job;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.accept_quote_customer(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.accept_quote_customer(uuid)
TO authenticated;



-- ============================================================
-- 5. CUSTOMER APPROVE COMPLETED JOB
--
-- De nuevo:
-- no duplicamos ledger/gamificación.
--
-- Validamos ownership y después usamos
-- approve_completed_job_trusted().
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_completed_job(
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
    -- CUSTOMER PROFILE
    -- --------------------------------------------------------

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
    -- OWNERSHIP
    -- --------------------------------------------------------

    IF v_job.client_id IS DISTINCT FROM v_user_id THEN

        RAISE EXCEPTION 'JOB_NOT_OWNED_BY_CUSTOMER';

    END IF;


    -- --------------------------------------------------------
    -- IDEMPOTENCIA
    -- --------------------------------------------------------

    IF v_job.status = 'customer_approved' THEN
        RETURN v_job;
    END IF;


    IF v_job.status <> 'work_completed' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;


    -- --------------------------------------------------------
    -- MOTOR FINANCIERO EXISTENTE
    --
    -- Genera:
    -- professional earning
    -- FIXIS commission
    -- gamification
    -- total_jobs
    -- customer_approved
    -- --------------------------------------------------------

    PERFORM public.approve_completed_job_trusted(
        p_job_id
    );


    SELECT *
    INTO v_job

    FROM public.jobs

    WHERE id = p_job_id;


    RETURN v_job;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.approve_completed_job(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.approve_completed_job(uuid)
TO authenticated;



-- ============================================================
-- 6. TRUSTED RPCS CONTINÚAN BLOQUEADAS AL CLIENTE
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.accept_quote_trusted(uuid)
FROM PUBLIC, anon, authenticated;


REVOKE EXECUTE
ON FUNCTION public.approve_completed_job_trusted(uuid)
FROM PUBLIC, anon, authenticated;


COMMIT;