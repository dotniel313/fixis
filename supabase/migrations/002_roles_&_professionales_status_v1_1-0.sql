BEGIN;

-- ============================================================
-- FIXIS PRO v1.1.0
-- MIGRATION 002
-- ROLES & PROFESSIONAL STATUS
-- ============================================================


-- ------------------------------------------------------------
-- 1. NUEVAS COLUMNAS
-- ------------------------------------------------------------

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS role text;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS verification_status text;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS account_status text;


-- ------------------------------------------------------------
-- 2. BACKFILL DE USUARIOS EXISTENTES
-- Ambos perfiles actuales provienen de solicitudes aprobadas.
-- ------------------------------------------------------------

UPDATE public.profiles p
SET
    role = 'professional',
    verification_status = 'approved',
    account_status = 'active'
WHERE EXISTS (
    SELECT 1
    FROM public.professionals_pending pp
    WHERE LOWER(TRIM(pp.email)) = LOWER(TRIM(p.email))
      AND pp.status = 'approved'
);


-- ------------------------------------------------------------
-- 3. COMPLETAR DATOS FALTANTES DEL PROFILE DESDE PENDING
-- Solo rellena cuando profiles está vacío.
-- ------------------------------------------------------------

UPDATE public.profiles p
SET
    full_name = COALESCE(p.full_name, pp.fullname),
    category = COALESCE(p.category, pp.category),
    city = COALESCE(p.city, pp.city),
    phone = COALESCE(p.phone, pp.phone),
    experience = COALESCE(p.experience, pp.experience),
    bank = COALESCE(p.bank, pp.bank),
    account_type = COALESCE(p.account_type, pp.account_type),
    account_number = COALESCE(p.account_number, pp.account_number)
FROM public.professionals_pending pp
WHERE LOWER(TRIM(pp.email)) = LOWER(TRIM(p.email))
  AND pp.status = 'approved';


-- ------------------------------------------------------------
-- 4. DEFAULTS PARA FUTUROS PROFILES
-- NOTA:
-- por ahora dejamos defaults neutrales/conservadores.
-- ------------------------------------------------------------

ALTER TABLE public.profiles
ALTER COLUMN role SET DEFAULT 'customer';

ALTER TABLE public.profiles
ALTER COLUMN verification_status SET DEFAULT 'pending';

ALTER TABLE public.profiles
ALTER COLUMN account_status SET DEFAULT 'active';


-- ------------------------------------------------------------
-- 5. VALIDACIONES
-- ------------------------------------------------------------

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_role_check
CHECK (
    role IN (
        'customer',
        'professional',
        'admin'
    )
);


ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_verification_status_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_verification_status_check
CHECK (
    verification_status IN (
        'pending',
        'approved',
        'rejected'
    )
);


ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_account_status_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_account_status_check
CHECK (
    account_status IN (
        'active',
        'suspended',
        'blocked'
    )
);


-- ------------------------------------------------------------
-- 6. HACER COLUMNAS OBLIGATORIAS
-- después del backfill.
-- ------------------------------------------------------------

ALTER TABLE public.profiles
ALTER COLUMN role SET NOT NULL;

ALTER TABLE public.profiles
ALTER COLUMN verification_status SET NOT NULL;

ALTER TABLE public.profiles
ALTER COLUMN account_status SET NOT NULL;


-- ------------------------------------------------------------
-- 7. ÍNDICE
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_profiles_role_status
ON public.profiles(
    role,
    verification_status,
    account_status
);


-- ------------------------------------------------------------
-- 8. EVITAR QUE FLUTTER MODIFIQUE CAMPOS DE SEGURIDAD
-- ------------------------------------------------------------

REVOKE UPDATE (
    role,
    verification_status,
    account_status
)
ON public.profiles
FROM authenticated;


-- ------------------------------------------------------------
-- 9. REEMPLAZAR accept_job()
-- ------------------------------------------------------------

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
    v_profile public.profiles;
    v_job public.jobs;
BEGIN

    v_user_id := auth.uid();


    -- --------------------------------------------------------
    -- AUTENTICACIÓN
    -- --------------------------------------------------------

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    -- --------------------------------------------------------
    -- OBTENER PROFILE
    -- --------------------------------------------------------

    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'PROFILE_NOT_FOUND';
    END IF;


    -- --------------------------------------------------------
    -- VALIDAR ROLE
    -- --------------------------------------------------------

    IF v_profile.role <> 'professional' THEN
        RAISE EXCEPTION 'NOT_A_PROFESSIONAL';
    END IF;


    -- --------------------------------------------------------
    -- VALIDAR VERIFICACIÓN
    -- --------------------------------------------------------

    IF v_profile.verification_status <> 'approved' THEN
        RAISE EXCEPTION 'PROFESSIONAL_NOT_APPROVED';
    END IF;


    -- --------------------------------------------------------
    -- VALIDAR ESTADO DE CUENTA
    -- --------------------------------------------------------

    IF v_profile.account_status <> 'active' THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;


    -- --------------------------------------------------------
    -- ACEPTACIÓN ATÓMICA
    -- --------------------------------------------------------

    UPDATE public.jobs
    SET
        assigned_pro_id = v_user_id,
        status = 'in_progress'
    WHERE id = p_job_id
      AND status = 'pending'
      AND assigned_pro_id IS NULL
    RETURNING *
    INTO v_job;


    -- --------------------------------------------------------
    -- TRABAJO NO DISPONIBLE
    -- --------------------------------------------------------

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


-- ------------------------------------------------------------
-- 10. PERMISOS RPC
-- ------------------------------------------------------------

REVOKE EXECUTE
ON FUNCTION public.accept_job(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.accept_job(uuid)
TO authenticated;


COMMIT;