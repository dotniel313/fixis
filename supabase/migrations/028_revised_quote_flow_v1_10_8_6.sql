BEGIN;

-- ============================================================
-- FIXIS PRO
-- v1.10.8.6-dev
-- Revised Quote / Change of Scope
--
-- Objetivo:
-- - Versionar cotizaciones.
-- - Preservar cotización original.
-- - Permitir revisión únicamente después de arrived y antes
--   de iniciar el trabajo.
-- - Versionar snapshots financieros.
-- - Mantener máximo un snapshot financiero vigente por job.
-- - Preservar la regla de comisión congelada originalmente.
-- ============================================================


-- ============================================================
-- 01. QUOTES — VERSIONADO
-- ============================================================

ALTER TABLE public.quotes
    ADD COLUMN revision_number integer NOT NULL DEFAULT 1,
    ADD COLUMN parent_quote_id uuid,
    ADD COLUMN revision_reason text;


ALTER TABLE public.quotes
    DROP CONSTRAINT quotes_job_professional_unique;


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_revision_number_check
    CHECK (revision_number >= 1);


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_parent_quote_fk
    FOREIGN KEY (parent_quote_id)
    REFERENCES public.quotes(id)
    ON DELETE RESTRICT;


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_revision_parent_check
    CHECK (
        (
            revision_number = 1
            AND parent_quote_id IS NULL
        )
        OR
        (
            revision_number > 1
            AND parent_quote_id IS NOT NULL
        )
    );


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_revision_reason_check
    CHECK (
        revision_number = 1
        OR NULLIF(BTRIM(revision_reason), '') IS NOT NULL
    );


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_parent_not_self_check
    CHECK (
        parent_quote_id IS NULL
        OR parent_quote_id <> id
    );


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_job_professional_revision_unique
    UNIQUE (
        job_id,
        professional_id,
        revision_number
    );


CREATE INDEX quotes_parent_quote_idx
ON public.quotes(parent_quote_id)
WHERE parent_quote_id IS NOT NULL;


-- ============================================================
-- 02. QUOTE STATUS
-- ============================================================

ALTER TABLE public.quotes
    DROP CONSTRAINT quotes_status_check;


ALTER TABLE public.quotes
    ADD CONSTRAINT quotes_status_check
    CHECK (
        status = ANY (
            ARRAY[
                'draft'::text,
                'submitted'::text,
                'accepted'::text,
                'rejected'::text,
                'cancelled'::text,
                'expired'::text,
                'superseded'::text
            ]
        )
    );


-- ============================================================
-- 03. JOBS — REVISIÓN PENDIENTE
-- ============================================================

ALTER TABLE public.jobs
    ADD COLUMN pending_quote_revision_id uuid;


ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_pending_quote_revision_fk
    FOREIGN KEY (pending_quote_revision_id)
    REFERENCES public.quotes(id)
    ON DELETE SET NULL;


CREATE UNIQUE INDEX jobs_pending_quote_revision_unique_idx
ON public.jobs(pending_quote_revision_id)
WHERE pending_quote_revision_id IS NOT NULL;


ALTER TABLE public.jobs
    DROP CONSTRAINT jobs_status_check;


ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_status_check
    CHECK (
        status = ANY (
            ARRAY[
                'pending'::text,
                'accepted'::text,
                'quote_submitted'::text,
                'authorized'::text,
                'en_route'::text,
                'arrived'::text,
                'quote_revision_pending'::text,
                'in_progress'::text,
                'work_completed'::text,
                'customer_approved'::text,
                'completed'::text,
                'cancelled'::text
            ]
        )
    );


-- Si hay revisión pendiente, el job DEBE estar en
-- quote_revision_pending.
--
-- Si no está en quote_revision_pending, no puede conservar
-- pending_quote_revision_id.

ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_quote_revision_pending_consistency_check
    CHECK (
        (
            status = 'quote_revision_pending'
            AND pending_quote_revision_id IS NOT NULL
        )
        OR
        (
            status <> 'quote_revision_pending'
            AND pending_quote_revision_id IS NULL
        )
    );


ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_quote_revision_requires_accepted_quote_check
    CHECK (
        status <> 'quote_revision_pending'
        OR accepted_quote_id IS NOT NULL
    );


ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_quote_revision_not_current_quote_check
    CHECK (
        pending_quote_revision_id IS NULL
        OR pending_quote_revision_id IS DISTINCT FROM accepted_quote_id
    );


-- ============================================================
-- 04. FINANCIAL SNAPSHOTS — VERSIONADO
-- ============================================================

ALTER TABLE public.job_financial_snapshots
    ADD COLUMN is_current boolean NOT NULL DEFAULT true,
    ADD COLUMN superseded_at timestamptz,
    ADD COLUMN superseded_by_snapshot_id uuid;


ALTER TABLE public.job_financial_snapshots
    ADD CONSTRAINT financial_snapshot_superseded_by_fk
    FOREIGN KEY (superseded_by_snapshot_id)
    REFERENCES public.job_financial_snapshots(id)
    ON DELETE SET NULL;


ALTER TABLE public.job_financial_snapshots
    ADD CONSTRAINT financial_snapshot_not_supersede_self_check
    CHECK (
        superseded_by_snapshot_id IS NULL
        OR superseded_by_snapshot_id <> id
    );


-- Antes de esta migración existía UNIQUE(job_id),
-- por lo tanto todos los snapshots históricos existentes
-- son correctamente los vigentes.

UPDATE public.job_financial_snapshots
SET
    is_current = true,
    superseded_at = NULL,
    superseded_by_snapshot_id = NULL;


ALTER TABLE public.job_financial_snapshots
    DROP CONSTRAINT job_financial_snapshots_job_id_key;


CREATE UNIQUE INDEX job_financial_snapshots_one_current_per_job_idx
ON public.job_financial_snapshots(job_id)
WHERE is_current = true;


CREATE INDEX job_financial_snapshots_job_history_idx
ON public.job_financial_snapshots(
    job_id,
    created_at
);


ALTER TABLE public.job_financial_snapshots
    ADD CONSTRAINT financial_snapshot_current_state_check
    CHECK (
        (
            is_current = true
            AND superseded_at IS NULL
            AND superseded_by_snapshot_id IS NULL
        )
        OR
        (
            is_current = false
            AND superseded_at IS NOT NULL
        )
    );


-- ============================================================
-- 05. CREATE_QUOTE()
--
-- El constraint anterior era:
-- UNIQUE(job_id, professional_id)
--
-- Ahora es:
-- UNIQUE(job_id, professional_id, revision_number)
--
-- La cotización inicial siempre es revision_number = 1.
-- ============================================================

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
SET search_path TO ''
AS $function$
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


    SELECT *
    INTO v_job
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


    IF (
        p_labor_amount
        + p_materials_amount
        + p_other_amount
    ) <= 0
    THEN
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
        expires_at,
        revision_number,
        parent_quote_id,
        revision_reason
    )
    VALUES (
        p_job_id,
        v_user_id,
        p_labor_amount,
        p_materials_amount,
        p_other_amount,
        NULLIF(TRIM(p_notes), ''),
        'draft',
        p_expires_at,
        1,
        NULL,
        NULL
    )

    ON CONFLICT (
        job_id,
        professional_id,
        revision_number
    )

    DO UPDATE SET
        labor_amount = EXCLUDED.labor_amount,
        materials_amount = EXCLUDED.materials_amount,
        other_amount = EXCLUDED.other_amount,
        notes = EXCLUDED.notes,
        expires_at = EXCLUDED.expires_at

    WHERE public.quotes.status = 'draft'

    RETURNING *
    INTO v_quote;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    RETURN v_quote;

END;
$function$;


-- ============================================================
-- 06. SUBMIT_QUOTE_REVISION()
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_quote_revision(
    p_job_id uuid,
    p_labor_amount numeric,
    p_materials_amount numeric,
    p_other_amount numeric,
    p_revision_reason text,
    p_notes text DEFAULT NULL
)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_job public.jobs;
    v_parent_quote public.quotes;
    v_current_snapshot public.job_financial_snapshots;
    v_revision_number integer;
    v_quote public.quotes;
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


    IF v_profile.role <> 'professional' THEN
        RAISE EXCEPTION 'NOT_A_PROFESSIONAL';
    END IF;


    IF v_profile.verification_status <> 'approved' THEN
        RAISE EXCEPTION 'PROFESSIONAL_NOT_APPROVED';
    END IF;


    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;


    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = p_job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.assigned_pro_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
    END IF;


    IF v_job.status <> 'arrived' THEN
        RAISE EXCEPTION 'QUOTE_REVISION_ONLY_AFTER_ARRIVAL';
    END IF;


    IF v_job.pending_quote_revision_id IS NOT NULL THEN
        RAISE EXCEPTION 'QUOTE_REVISION_ALREADY_PENDING';
    END IF;


    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;


    IF NULLIF(BTRIM(p_revision_reason), '') IS NULL THEN
        RAISE EXCEPTION 'REVISION_REASON_REQUIRED';
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


    IF (
        p_labor_amount
        + p_materials_amount
        + p_other_amount
    ) <= 0
    THEN
        RAISE EXCEPTION 'QUOTE_TOTAL_MUST_BE_POSITIVE';
    END IF;


    SELECT *
    INTO v_parent_quote
    FROM public.quotes
    WHERE id = v_job.accepted_quote_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_parent_quote.status <> 'accepted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    IF v_parent_quote.professional_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'QUOTE_NOT_OWNED_BY_USER';
    END IF;


    SELECT *
    INTO v_current_snapshot
    FROM public.job_financial_snapshots
    WHERE job_id = v_job.id
      AND quote_id = v_job.accepted_quote_id
      AND is_current = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.payments
        WHERE job_id = v_job.id
    ) THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PAYMENT_ALREADY_EXISTS';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.financial_ledger_entries
        WHERE job_id = v_job.id
    ) THEN
        RAISE EXCEPTION 'QUOTE_REVISION_LEDGER_ALREADY_EXISTS';
    END IF;


    SELECT
        COALESCE(MAX(revision_number), 0) + 1
    INTO v_revision_number
    FROM public.quotes
    WHERE job_id = v_job.id
      AND professional_id = v_user_id;


    INSERT INTO public.quotes (
        job_id,
        professional_id,
        labor_amount,
        materials_amount,
        other_amount,
        notes,
        status,
        submitted_at,
        revision_number,
        parent_quote_id,
        revision_reason
    )
    VALUES (
        v_job.id,
        v_user_id,
        p_labor_amount,
        p_materials_amount,
        p_other_amount,
        NULLIF(TRIM(p_notes), ''),
        'submitted',
        now(),
        v_revision_number,
        v_parent_quote.id,
        BTRIM(p_revision_reason)
    )
    RETURNING *
    INTO v_quote;


    UPDATE public.jobs
    SET
        status = 'quote_revision_pending',
        pending_quote_revision_id = v_quote.id
    WHERE id = v_job.id;


    RETURN v_quote;

END;
$function$;


-- ============================================================
-- 07. ACCEPT_QUOTE_REVISION_CUSTOMER()
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_quote_revision_customer(
    p_quote_id uuid
)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;

    v_revision public.quotes;
    v_parent_quote public.quotes;
    v_job public.jobs;

    v_old_snapshot public.job_financial_snapshots;
    v_new_snapshot public.job_financial_snapshots;

    v_rule public.commission_rules;

    v_basis_amount numeric(12,2);
    v_commission numeric(12,2);
    v_professional_amount numeric(12,2);
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


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_revision.parent_quote_id IS NULL
       OR v_revision.revision_number <= 1
    THEN
        RAISE EXCEPTION 'NOT_A_QUOTE_REVISION';
    END IF;


    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = v_revision.job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.client_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_OWNED_BY_CUSTOMER';
    END IF;


    -- Idempotencia.
    IF v_revision.status = 'accepted'
       AND v_job.accepted_quote_id = v_revision.id
       AND v_job.pending_quote_revision_id IS NULL
    THEN
        RETURN v_revision;
    END IF;


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id
    FOR UPDATE;


    IF v_job.status <> 'quote_revision_pending' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.pending_quote_revision_id
       IS DISTINCT FROM v_revision.id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PENDING';
    END IF;


    IF v_revision.status <> 'submitted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;


    IF v_revision.parent_quote_id
       IS DISTINCT FROM v_job.accepted_quote_id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PARENT_MISMATCH';
    END IF;


    IF v_revision.professional_id
       IS DISTINCT FROM v_job.assigned_pro_id
    THEN
        RAISE EXCEPTION 'QUOTE_PROFESSIONAL_MISMATCH';
    END IF;


    SELECT *
    INTO v_parent_quote
    FROM public.quotes
    WHERE id = v_job.accepted_quote_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_parent_quote.status <> 'accepted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.payments
        WHERE job_id = v_job.id
    ) THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PAYMENT_ALREADY_EXISTS';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.financial_ledger_entries
        WHERE job_id = v_job.id
    ) THEN
        RAISE EXCEPTION 'QUOTE_REVISION_LEDGER_ALREADY_EXISTS';
    END IF;


    SELECT *
    INTO v_old_snapshot
    FROM public.job_financial_snapshots
    WHERE job_id = v_job.id
      AND quote_id = v_job.accepted_quote_id
      AND is_current = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;


    SELECT *
    INTO v_rule
    FROM public.commission_rules
    WHERE id = v_old_snapshot.commission_rule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'COMMISSION_RULE_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- Recalcular usando la regla congelada original.
    -- --------------------------------------------------------

    IF v_old_snapshot.commission_basis = 'labor' THEN

        v_basis_amount := v_revision.labor_amount;

    ELSIF v_old_snapshot.commission_basis = 'total' THEN

        v_basis_amount := v_revision.total_amount;

    ELSE

        RAISE EXCEPTION 'INVALID_COMMISSION_BASIS';

    END IF;


    v_commission :=
        ROUND(
            (
                v_basis_amount
                * v_old_snapshot.commission_rate_percent
                / 100
            ),
            2
        );


    IF v_rule.minimum_commission IS NOT NULL THEN
        v_commission :=
            GREATEST(
                v_commission,
                v_rule.minimum_commission
            );
    END IF;


    IF v_rule.maximum_commission IS NOT NULL THEN
        v_commission :=
            LEAST(
                v_commission,
                v_rule.maximum_commission
            );
    END IF;


    v_commission :=
        LEAST(
            v_commission,
            v_revision.total_amount
        );


    v_professional_amount :=
        ROUND(
            v_revision.total_amount
            - v_commission,
            2
        );


    -- --------------------------------------------------------
    -- Snapshot anterior deja de ser current.
    -- --------------------------------------------------------

    UPDATE public.job_financial_snapshots
    SET
        is_current = false,
        superseded_at = now()
    WHERE id = v_old_snapshot.id;


    -- --------------------------------------------------------
    -- Nuevo snapshot.
    -- --------------------------------------------------------

    INSERT INTO public.job_financial_snapshots (
        job_id,
        quote_id,
        professional_id,

        commission_rule_id,
        commission_rule_code,
        commission_basis,

        labor_amount,
        materials_amount,
        other_amount,
        gross_amount,

        commission_basis_amount,
        commission_rate_percent,
        commission_amount,
        professional_amount,

        is_current
    )
    VALUES (
        v_job.id,
        v_revision.id,
        v_revision.professional_id,

        v_old_snapshot.commission_rule_id,
        v_old_snapshot.commission_rule_code,
        v_old_snapshot.commission_basis,

        v_revision.labor_amount,
        v_revision.materials_amount,
        v_revision.other_amount,
        v_revision.total_amount,

        v_basis_amount,
        v_old_snapshot.commission_rate_percent,
        v_commission,
        v_professional_amount,

        true
    )
    RETURNING *
    INTO v_new_snapshot;


    UPDATE public.job_financial_snapshots
    SET superseded_by_snapshot_id = v_new_snapshot.id
    WHERE id = v_old_snapshot.id;


    -- --------------------------------------------------------
    -- Quote original pasa a histórico.
    -- --------------------------------------------------------

    UPDATE public.quotes
    SET status = 'superseded'
    WHERE id = v_parent_quote.id;


    -- --------------------------------------------------------
    -- Revisión pasa a ser la cotización aceptada.
    -- --------------------------------------------------------

    UPDATE public.quotes
    SET
        status = 'accepted',
        accepted_at = now()
    WHERE id = v_revision.id
    RETURNING *
    INTO v_revision;


    -- --------------------------------------------------------
    -- El job vuelve a arrived.
    -- --------------------------------------------------------

    UPDATE public.jobs
    SET
        status = 'arrived',
        accepted_quote_id = v_revision.id,
        pending_quote_revision_id = NULL
    WHERE id = v_job.id;


    RETURN v_revision;

END;
$function$;


-- ============================================================
-- 08. REJECT_QUOTE_REVISION_CUSTOMER()
-- ============================================================

CREATE OR REPLACE FUNCTION public.reject_quote_revision_customer(
    p_quote_id uuid
)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_revision public.quotes;
    v_job public.jobs;
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


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_revision.parent_quote_id IS NULL
       OR v_revision.revision_number <= 1
    THEN
        RAISE EXCEPTION 'NOT_A_QUOTE_REVISION';
    END IF;


    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = v_revision.job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.client_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_OWNED_BY_CUSTOMER';
    END IF;


    -- Idempotencia.
    IF v_revision.status = 'rejected'
       AND v_job.pending_quote_revision_id IS NULL
    THEN
        RETURN v_revision;
    END IF;


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id
    FOR UPDATE;


    IF v_job.status <> 'quote_revision_pending' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.pending_quote_revision_id
       IS DISTINCT FROM v_revision.id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PENDING';
    END IF;


    IF v_revision.status <> 'submitted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    IF v_revision.parent_quote_id
       IS DISTINCT FROM v_job.accepted_quote_id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PARENT_MISMATCH';
    END IF;


    UPDATE public.quotes
    SET
        status = 'rejected',
        rejected_at = now()
    WHERE id = v_revision.id
    RETURNING *
    INTO v_revision;


    UPDATE public.jobs
    SET
        status = 'arrived',
        pending_quote_revision_id = NULL
    WHERE id = v_job.id;


    RETURN v_revision;

END;
$function$;


-- ============================================================
-- 09. CANCEL_QUOTE_REVISION()
-- ============================================================

CREATE OR REPLACE FUNCTION public.cancel_quote_revision(
    p_quote_id uuid
)
RETURNS public.quotes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_profile public.profiles;
    v_revision public.quotes;
    v_job public.jobs;
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


    IF v_profile.role <> 'professional' THEN
        RAISE EXCEPTION 'NOT_A_PROFESSIONAL';
    END IF;


    IF v_profile.verification_status <> 'approved' THEN
        RAISE EXCEPTION 'PROFESSIONAL_NOT_APPROVED';
    END IF;


    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QUOTE_NOT_FOUND';
    END IF;


    IF v_revision.parent_quote_id IS NULL
       OR v_revision.revision_number <= 1
    THEN
        RAISE EXCEPTION 'NOT_A_QUOTE_REVISION';
    END IF;


    SELECT *
    INTO v_job
    FROM public.jobs
    WHERE id = v_revision.job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.assigned_pro_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
    END IF;


    IF v_revision.professional_id IS DISTINCT FROM v_user_id THEN
        RAISE EXCEPTION 'QUOTE_NOT_OWNED_BY_USER';
    END IF;


    -- Idempotencia.
    IF v_revision.status = 'cancelled'
       AND v_job.pending_quote_revision_id IS NULL
    THEN
        RETURN v_revision;
    END IF;


    SELECT *
    INTO v_revision
    FROM public.quotes
    WHERE id = p_quote_id
    FOR UPDATE;


    IF v_job.status <> 'quote_revision_pending' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.pending_quote_revision_id
       IS DISTINCT FROM v_revision.id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PENDING';
    END IF;


    IF v_revision.status <> 'submitted' THEN
        RAISE EXCEPTION 'INVALID_QUOTE_STATE';
    END IF;


    IF v_revision.parent_quote_id
       IS DISTINCT FROM v_job.accepted_quote_id
    THEN
        RAISE EXCEPTION 'QUOTE_REVISION_PARENT_MISMATCH';
    END IF;


    UPDATE public.quotes
    SET status = 'cancelled'
    WHERE id = v_revision.id
    RETURNING *
    INTO v_revision;


    UPDATE public.jobs
    SET
        status = 'arrived',
        pending_quote_revision_id = NULL
    WHERE id = v_job.id;


    RETURN v_revision;

END;
$function$;


-- ============================================================
-- 10. PREPARE_JOB_PAYMENT()
--
-- Antes:
--   snapshot WHERE job_id = p_job_id
--
-- Ahora:
--   job_id
--   + accepted_quote_id
--   + is_current
-- ============================================================

CREATE OR REPLACE FUNCTION public.prepare_job_payment(
    p_job_id uuid,
    p_payment_method text
)
RETURNS public.payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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


    IF p_payment_method NOT IN (
        'bank_transfer',
        'card'
    ) THEN
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


    -- Idempotencia: payment existente gana.

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
    WHERE job_id = p_job_id
      AND quote_id = v_job.accepted_quote_id
      AND is_current = true;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;


    IF v_snapshot.professional_id
       IS DISTINCT FROM v_job.assigned_pro_id
    THEN
        RAISE EXCEPTION 'SNAPSHOT_PROFESSIONAL_MISMATCH';
    END IF;


    IF p_payment_method = 'bank_transfer' THEN

        v_initial_status := 'pending_transfer';

    ELSE

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
            WHEN p_payment_method = 'bank_transfer'
                THEN 'manual_bank_transfer'
            ELSE NULL
        END
    )
    RETURNING *
    INTO v_payment;


    RETURN v_payment;

END;
$function$;


-- ============================================================
-- 11. PERMISSIONS
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.submit_quote_revision(
    uuid,
    numeric,
    numeric,
    numeric,
    text,
    text
)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.submit_quote_revision(
    uuid,
    numeric,
    numeric,
    numeric,
    text,
    text
)
TO authenticated;


REVOKE EXECUTE
ON FUNCTION public.accept_quote_revision_customer(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.accept_quote_revision_customer(uuid)
TO authenticated;


REVOKE EXECUTE
ON FUNCTION public.reject_quote_revision_customer(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.reject_quote_revision_customer(uuid)
TO authenticated;


REVOKE EXECUTE
ON FUNCTION public.cancel_quote_revision(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.cancel_quote_revision(uuid)
TO authenticated;


-- Reafirmar permisos sobre funciones reemplazadas.

REVOKE EXECUTE
ON FUNCTION public.create_quote(
    uuid,
    numeric,
    numeric,
    numeric,
    text,
    timestamptz
)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.create_quote(
    uuid,
    numeric,
    numeric,
    numeric,
    text,
    timestamptz
)
TO authenticated;


REVOKE EXECUTE
ON FUNCTION public.prepare_job_payment(uuid, text)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.prepare_job_payment(uuid, text)
TO authenticated;


-- ============================================================
-- 12. COMMENTS / DOCUMENTATION
-- ============================================================

COMMENT ON COLUMN public.quotes.revision_number IS
'Número secuencial de versión de la cotización dentro del job/profesional.';


COMMENT ON COLUMN public.quotes.parent_quote_id IS
'Cotización aceptada que dio origen a esta revisión. NULL para cotización inicial.';


COMMENT ON COLUMN public.quotes.revision_reason IS
'Motivo obligatorio del cambio de alcance en revisiones.';


COMMENT ON COLUMN public.jobs.pending_quote_revision_id IS
'Revisión de cotización pendiente de decisión del cliente.';


COMMENT ON COLUMN public.job_financial_snapshots.is_current IS
'Indica cuál snapshot representa actualmente la economía autorizada del job.';


COMMENT ON COLUMN public.job_financial_snapshots.superseded_at IS
'Fecha en que el snapshot dejó de ser la economía vigente.';


COMMENT ON COLUMN public.job_financial_snapshots.superseded_by_snapshot_id IS
'Snapshot que reemplazó a este snapshot financiero.';


COMMIT;
