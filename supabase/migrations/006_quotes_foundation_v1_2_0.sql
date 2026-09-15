-- ============================================================
-- FIXIS PRO v1.2.0
-- MIGRATION 006 - QUOTES FOUNDATION
-- Idempotente para el estado esperado del proyecto.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.quotes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id uuid NOT NULL,
    professional_id uuid NOT NULL,
    labor_amount numeric(12,2) NOT NULL DEFAULT 0,
    materials_amount numeric(12,2) NOT NULL DEFAULT 0,
    other_amount numeric(12,2) NOT NULL DEFAULT 0,
    total_amount numeric(12,2)
        GENERATED ALWAYS AS (
            labor_amount + materials_amount + other_amount
        ) STORED,
    notes text,
    status text NOT NULL DEFAULT 'draft',
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    submitted_at timestamptz,
    accepted_at timestamptz,
    rejected_at timestamptz,
    expires_at timestamptz,

    CONSTRAINT quotes_job_fk
        FOREIGN KEY (job_id)
        REFERENCES public.jobs(id)
        ON DELETE CASCADE,

    CONSTRAINT quotes_professional_fk
        FOREIGN KEY (professional_id)
        REFERENCES public.profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT quotes_job_professional_unique
        UNIQUE (job_id, professional_id),

    CONSTRAINT quotes_labor_amount_check
        CHECK (labor_amount >= 0 AND labor_amount <= 999999.99),

    CONSTRAINT quotes_materials_amount_check
        CHECK (materials_amount >= 0 AND materials_amount <= 999999.99),

    CONSTRAINT quotes_other_amount_check
        CHECK (other_amount >= 0 AND other_amount <= 999999.99),

    CONSTRAINT quotes_total_positive_check
        CHECK (total_amount > 0),

    CONSTRAINT quotes_status_check
        CHECK (
            status IN (
                'draft',
                'submitted',
                'accepted',
                'rejected',
                'cancelled',
                'expired'
            )
        )
);

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS accepted_quote_id uuid;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'jobs_accepted_quote_fk'
          AND conrelid = 'public.jobs'::regclass
    ) THEN
        ALTER TABLE public.jobs
        ADD CONSTRAINT jobs_accepted_quote_fk
        FOREIGN KEY (accepted_quote_id)
        REFERENCES public.quotes(id)
        ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_quotes_job
ON public.quotes(job_id);

CREATE INDEX IF NOT EXISTS idx_quotes_professional_created
ON public.quotes(professional_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quotes_status
ON public.quotes(status);

ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quotes_select_own" ON public.quotes;

CREATE POLICY "quotes_select_own"
ON public.quotes
FOR SELECT
TO authenticated
USING (professional_id = (SELECT auth.uid()));

REVOKE ALL ON public.quotes FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON public.quotes FROM authenticated;
GRANT SELECT ON public.quotes TO authenticated;

-- ------------------------------------------------------------
-- accept_job: pending -> accepted
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_job(p_job_id uuid)
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

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT * INTO v_profile
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

    UPDATE public.jobs
    SET assigned_pro_id = v_user_id,
        status = 'accepted'
    WHERE id = p_job_id
      AND status = 'pending'
      AND assigned_pro_id IS NULL
    RETURNING * INTO v_job;

    IF NOT FOUND THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.jobs WHERE id = p_job_id
        ) THEN
            RAISE EXCEPTION 'JOB_NOT_FOUND';
        END IF;

        RAISE EXCEPTION 'JOB_ALREADY_TAKEN';
    END IF;

    RETURN v_job;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_job(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_job(uuid) TO authenticated;

-- ------------------------------------------------------------
-- create_quote: crea/actualiza únicamente un draft mientras el
-- job continúa en accepted. Una cotización enviada queda bloqueada.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_quote(
    p_job_id uuid,
    p_labor_amount numeric,
    p_materials_amount numeric,
    p_other_amount numeric,
    p_notes text DEFAULT NULL,
    p_expires_at timestamptz DEFAULT NULL
)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_job public.jobs;
    v_quote public.quotes;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT * INTO v_profile
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

    SELECT * INTO v_job
    FROM public.jobs
    WHERE id = p_job_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;

    IF v_job.assigned_pro_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
    END IF;

    IF v_job.status <> 'accepted' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;

    IF p_labor_amount < 0
       OR p_materials_amount < 0
       OR p_other_amount < 0
    THEN
        RAISE EXCEPTION 'INVALID_QUOTE_AMOUNT';
    END IF;

    IF p_labor_amount > 999999.99
       OR p_materials_amount > 999999.99
       OR p_other_amount > 999999.99
    THEN
        RAISE EXCEPTION 'INVALID_QUOTE_AMOUNT';
    END IF;

    IF (p_labor_amount + p_materials_amount + p_other_amount) <= 0 THEN
        RAISE EXCEPTION 'QUOTE_TOTAL_MUST_BE_POSITIVE';
    END IF;

    INSERT INTO public.quotes (
        job_id,
        professional_id,
        labor_amount,
        materials_amount,
        other_amount,
        notes,
        status,
        expires_at
    )
    VALUES (
        p_job_id,
        v_user_id,
        p_labor_amount,
        p_materials_amount,
        p_other_amount,
        NULLIF(TRIM(p_notes), ''),
        'draft',
        p_expires_at
    )
    ON CONFLICT (job_id, professional_id)
    DO UPDATE SET
        labor_amount = EXCLUDED.labor_amount,
        materials_amount = EXCLUDED.materials_amount,
        other_amount = EXCLUDED.other_amount,
        notes = EXCLUDED.notes,
        expires_at = EXCLUDED.expires_at
    WHERE public.quotes.status = 'draft'
    RETURNING * INTO v_quote;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;

    RETURN v_quote;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_quote(
    uuid, numeric, numeric, numeric, text, timestamptz
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_quote(
    uuid, numeric, numeric, numeric, text, timestamptz
) TO authenticated;

-- ------------------------------------------------------------
-- submit_quote: draft -> submitted y job accepted -> quote_submitted
-- La operación es atómica; si el job no está en accepted, falla todo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_quote(p_quote_id uuid)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_quote public.quotes;
    v_updated_job public.jobs;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    SELECT * INTO v_quote
    FROM public.quotes
    WHERE id = p_quote_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;

    IF v_quote.professional_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'QUOTE_NOT_OWNED_BY_USER';
    END IF;

    IF v_quote.status <> 'draft' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;

    UPDATE public.jobs
    SET status = 'quote_submitted'
    WHERE id = v_quote.job_id
      AND assigned_pro_id = v_user_id
      AND status = 'accepted'
    RETURNING * INTO v_updated_job;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;

    UPDATE public.quotes
    SET status = 'submitted',
        submitted_at = now()
    WHERE id = p_quote_id
    RETURNING * INTO v_quote;

    RETURN v_quote;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_quote(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_quote(uuid) TO authenticated;

COMMIT;
