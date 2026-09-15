-- FIXIS PRO v1.1.0
-- Migration 003 - Secure job actions compatibility layer
-- Objetivo: mantener accept_job seguro y reemplazar UPDATE directo de completeJob().

BEGIN;

CREATE OR REPLACE FUNCTION public.complete_job_v1(
    p_job_id uuid
)
RETURNS public.jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_job public.jobs;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = v_user_id
          AND p.role = 'professional'
          AND p.verification_status = 'approved'
          AND p.account_status = 'active'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.profiles p WHERE p.id = v_user_id
        ) THEN
            RAISE EXCEPTION 'PROFILE_NOT_FOUND';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = v_user_id
              AND p.role <> 'professional'
        ) THEN
            RAISE EXCEPTION 'NOT_A_PROFESSIONAL';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = v_user_id
              AND p.verification_status <> 'approved'
        ) THEN
            RAISE EXCEPTION 'PROFESSIONAL_NOT_APPROVED';
        END IF;

        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    UPDATE public.jobs
       SET status = 'completed'
     WHERE id = p_job_id
       AND assigned_pro_id = v_user_id
       AND status = 'in_progress'
    RETURNING * INTO v_job;

    IF FOUND THEN
        RETURN v_job;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.jobs WHERE id = p_job_id
    ) THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.jobs
        WHERE id = p_job_id
          AND assigned_pro_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'JOB_NOT_ASSIGNED';
    END IF;

    RAISE EXCEPTION 'INVALID_JOB_STATE';
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.complete_job_v1(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.complete_job_v1(uuid)
TO authenticated;

COMMIT;
