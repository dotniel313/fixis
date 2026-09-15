BEGIN;

-- ============================================================
-- FIXIS - MIGRATION 001
-- SECURITY FOUNDATION
-- ============================================================


-- ============================================================
-- 1. FOREIGN KEYS
-- ============================================================

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_auth_user_fk
FOREIGN KEY (id)
REFERENCES auth.users(id)
ON DELETE CASCADE;


ALTER TABLE public.expert_gamification
ADD CONSTRAINT expert_gamification_profile_fk
FOREIGN KEY (pro_id)
REFERENCES public.profiles(id)
ON DELETE CASCADE;


ALTER TABLE public.wallet_transactions
ADD CONSTRAINT wallet_transactions_profile_fk
FOREIGN KEY (pro_id)
REFERENCES public.profiles(id)
ON DELETE RESTRICT;


ALTER TABLE public.jobs
ADD CONSTRAINT jobs_assigned_pro_fk
FOREIGN KEY (assigned_pro_id)
REFERENCES public.profiles(id)
ON DELETE SET NULL;



-- ============================================================
-- 2. CORREGIR DEFAULTS DE GAMIFICACIÓN
-- Solo afecta nuevos registros.
-- ============================================================

ALTER TABLE public.expert_gamification
ALTER COLUMN current_rank SET DEFAULT 'Inicial';

ALTER TABLE public.expert_gamification
ALTER COLUMN completed_jobs_count SET DEFAULT 0;

ALTER TABLE public.expert_gamification
ALTER COLUMN target_jobs_count SET DEFAULT 5;

ALTER TABLE public.expert_gamification
ALTER COLUMN badges SET DEFAULT '[]'::jsonb;



-- ============================================================
-- 3. ÍNDICES MVP
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_jobs_pending_created
ON public.jobs(created_at DESC)
WHERE status = 'pending'
AND assigned_pro_id IS NULL;


CREATE INDEX IF NOT EXISTS idx_jobs_assigned_pro_created
ON public.jobs(assigned_pro_id, created_at DESC)
WHERE assigned_pro_id IS NOT NULL;


CREATE INDEX IF NOT EXISTS idx_wallet_transactions_pro_created
ON public.wallet_transactions(pro_id, created_at DESC);


CREATE INDEX IF NOT EXISTS idx_professionals_pending_status_created
ON public.professionals_pending(status, created_at DESC);



-- ============================================================
-- 4. ASEGURAR RLS
-- ============================================================

ALTER TABLE public.profiles
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.jobs
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_transactions
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.expert_gamification
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.professionals_pending
ENABLE ROW LEVEL SECURITY;



-- ============================================================
-- 5. WALLET
-- APP = SOLO LECTURA
-- ============================================================

DROP POLICY IF EXISTS
"Insertar mis transacciones"
ON public.wallet_transactions;

DROP POLICY IF EXISTS
"Ver mis transacciones"
ON public.wallet_transactions;

DROP POLICY IF EXISTS
"wallet_select_own"
ON public.wallet_transactions;


CREATE POLICY "wallet_select_own"
ON public.wallet_transactions
FOR SELECT
TO authenticated
USING (
    pro_id = (SELECT auth.uid())
);


REVOKE INSERT, UPDATE, DELETE
ON public.wallet_transactions
FROM anon, authenticated;

GRANT SELECT
ON public.wallet_transactions
TO authenticated;



-- ============================================================
-- 6. GAMIFICACIÓN
-- APP = SOLO LECTURA
-- ============================================================

DROP POLICY IF EXISTS
"Actualizar mi gamificacion"
ON public.expert_gamification;

DROP POLICY IF EXISTS
"Crear registro de gamificacion"
ON public.expert_gamification;

DROP POLICY IF EXISTS
"Ver mi gamificacion"
ON public.expert_gamification;

DROP POLICY IF EXISTS
"gamification_select_own"
ON public.expert_gamification;


CREATE POLICY "gamification_select_own"
ON public.expert_gamification
FOR SELECT
TO authenticated
USING (
    pro_id = (SELECT auth.uid())
);


REVOKE INSERT, UPDATE, DELETE
ON public.expert_gamification
FROM anon, authenticated;

GRANT SELECT
ON public.expert_gamification
TO authenticated;



-- ============================================================
-- 7. JOBS
-- QUITAR ACCESO PÚBLICO Y ESCRITURA DIRECTA
-- ============================================================

DROP POLICY IF EXISTS
"Crear trabajos de prueba"
ON public.jobs;

DROP POLICY IF EXISTS
"Lectura publica de trabajos pendientes"
ON public.jobs;

DROP POLICY IF EXISTS
"Actualizar mis trabajos"
ON public.jobs;

DROP POLICY IF EXISTS
"Expertos pueden actualizar trabajos"
ON public.jobs;

DROP POLICY IF EXISTS
"Expertos pueden ver trabajos"
ON public.jobs;

DROP POLICY IF EXISTS
"jobs_select_for_professional"
ON public.jobs;


CREATE POLICY "jobs_select_for_professional"
ON public.jobs
FOR SELECT
TO authenticated
USING (
    status = 'pending'
    OR assigned_pro_id = (SELECT auth.uid())
);


REVOKE SELECT, INSERT, UPDATE, DELETE
ON public.jobs
FROM anon;

REVOKE INSERT, UPDATE, DELETE
ON public.jobs
FROM authenticated;

GRANT SELECT
ON public.jobs
TO authenticated;



-- ============================================================
-- 8. PROFILES
-- ============================================================

DROP POLICY IF EXISTS
"Usuarios pueden actualizar su propio perfil"
ON public.profiles;

DROP POLICY IF EXISTS
"Usuarios pueden ver su propio perfil"
ON public.profiles;

DROP POLICY IF EXISTS
"profiles_select_own"
ON public.profiles;

DROP POLICY IF EXISTS
"profiles_update_own"
ON public.profiles;


CREATE POLICY "profiles_select_own"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    id = (SELECT auth.uid())
);


CREATE POLICY "profiles_update_own"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    id = (SELECT auth.uid())
)
WITH CHECK (
    id = (SELECT auth.uid())
);


REVOKE ALL
ON public.profiles
FROM anon;


-- quitar UPDATE general
REVOKE UPDATE
ON public.profiles
FROM authenticated;


-- puede leer su fila
GRANT SELECT
ON public.profiles
TO authenticated;


-- Solo campos editables por el usuario
GRANT UPDATE (
    full_name,
    phone,
    email,
    avatar_url,
    city,
    experience,
    bank,
    account_type,
    account_number,
    bio
)
ON public.profiles
TO authenticated;



-- ============================================================
-- 9. PROFESSIONALS_PENDING
-- mantener registro desde landing,
-- pero impedir lectura desde anon
-- ============================================================

REVOKE SELECT, UPDATE, DELETE
ON public.professionals_pending
FROM anon;

GRANT INSERT
ON public.professionals_pending
TO anon;



-- ============================================================
-- 10. ACCEPT_JOB RPC
-- aceptación atómica del trabajo
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_job(
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


    -- Usuario debe estar autenticado
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    -- Debe existir en profiles
    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = v_user_id
    ) THEN
        RAISE EXCEPTION 'PROFILE_NOT_FOUND';
    END IF;


    -- Asignación atómica:
    -- solamente funciona si continúa disponible.
    UPDATE public.jobs
    SET
        assigned_pro_id = v_user_id,
        status = 'in_progress'
    WHERE id = p_job_id
      AND status = 'pending'
      AND assigned_pro_id IS NULL
    RETURNING *
    INTO v_job;


    IF NOT FOUND THEN

        IF NOT EXISTS (
            SELECT 1
            FROM public.jobs
            WHERE id = p_job_id
        ) THEN
            RAISE EXCEPTION 'JOB_NOT_FOUND';
        END IF;

        RAISE EXCEPTION 'JOB_ALREADY_TAKEN';

    END IF;


    RETURN v_job;

END;
$$;


-- Las funciones Postgres reciben EXECUTE de PUBLIC por defecto.
-- Cerramos explícitamente.
REVOKE EXECUTE
ON FUNCTION public.accept_job(uuid)
FROM PUBLIC;

REVOKE EXECUTE
ON FUNCTION public.accept_job(uuid)
FROM anon;

GRANT EXECUTE
ON FUNCTION public.accept_job(uuid)
TO authenticated;


COMMIT;