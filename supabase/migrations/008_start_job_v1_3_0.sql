BEGIN;

-- ============================================================
-- FIXIS PRO v1.3.0
-- MIGRATION 008
-- START JOB
-- ============================================================

CREATE OR REPLACE FUNCTION public.start_job(
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

    IF v_job.status <> 'authorized' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;

    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.job_financial_snapshots f
        WHERE f.job_id = p_job_id
          AND f.quote_id = v_job.accepted_quote_id
    ) THEN
        RAISE EXCEPTION 'FINANCIAL_SNAPSHOT_REQUIRED';
    END IF;

    UPDATE public.jobs
    SET status = 'in_progress'
    WHERE id = p_job_id
    RETURNING *
    INTO v_job;

    RETURN v_job;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.start_job(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.start_job(uuid)
TO authenticated;

COMMIT;
