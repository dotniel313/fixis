BEGIN;

-- ============================================================
-- FIXIS PRO v1.8.0
-- MIGRATION 014
-- GEO MATCHING FOUNDATION
-- ============================================================


-- ============================================================
-- 1. POSTGIS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis
WITH SCHEMA extensions;


-- ============================================================
-- 2. NORMALIZACIÓN DE CATEGORÍAS
--
-- No modifica el texto visible.
-- Solo genera una clave comparable.
--
-- Plomería -> plomeria
-- Plomeria -> plomeria
-- Mecánica  -> mecanica
-- Mecanica  -> mecanica
-- ============================================================

CREATE OR REPLACE FUNCTION public.normalize_service_category(
    p_category text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT
        translate(
            lower(trim(COALESCE(p_category, ''))),
            'áéíóúüñÁÉÍÓÚÜÑ',
            'aeiouunAEIOUUN'
        );
$$;


REVOKE EXECUTE
ON FUNCTION public.normalize_service_category(text)
FROM PUBLIC, anon, authenticated;



-- ============================================================
-- 3. GEO + DISPONIBILIDAD EN PROFILES
-- ============================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_available boolean
NOT NULL DEFAULT false;


ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS service_radius_km numeric(5,2)
NOT NULL DEFAULT 8.00;


ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS current_latitude double precision;


ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS current_longitude double precision;


ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;


ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS service_location
extensions.geography(Point, 4326);


ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_service_radius_check;


ALTER TABLE public.profiles
ADD CONSTRAINT profiles_service_radius_check
CHECK (
    service_radius_km >= 1
    AND service_radius_km <= 100
);


ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_current_latitude_check;


ALTER TABLE public.profiles
ADD CONSTRAINT profiles_current_latitude_check
CHECK (
    current_latitude IS NULL
    OR (
        current_latitude >= -90
        AND current_latitude <= 90
    )
);


ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_current_longitude_check;


ALTER TABLE public.profiles
ADD CONSTRAINT profiles_current_longitude_check
CHECK (
    current_longitude IS NULL
    OR (
        current_longitude >= -180
        AND current_longitude <= 180
    )
);


CREATE INDEX IF NOT EXISTS idx_profiles_service_location
ON public.profiles
USING GIST(service_location);



-- ============================================================
-- 4. GEOGRAPHY EN JOBS
-- ============================================================

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS service_location
extensions.geography(Point, 4326);


-- Backfill únicamente donde existen ambas coordenadas.

UPDATE public.jobs
SET service_location =
    extensions.ST_SetSRID(
        extensions.ST_MakePoint(
            longitude,
            latitude
        ),
        4326
    )::extensions.geography
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
  AND service_location IS NULL;


CREATE INDEX IF NOT EXISTS idx_jobs_service_location
ON public.jobs
USING GIST(service_location);


CREATE INDEX IF NOT EXISTS idx_jobs_pending_category
ON public.jobs(status, category)
WHERE status = 'pending';



-- ============================================================
-- 5. ACTUALIZAR PRESENCIA / DISPONIBILIDAD DEL FIXI
--
-- Flutter no hace UPDATE directo de profiles para ubicación.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_professional_presence(

    p_is_available boolean,

    p_latitude double precision DEFAULT NULL,

    p_longitude double precision DEFAULT NULL,

    p_service_radius_km numeric DEFAULT NULL

)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;
    v_profile public.profiles;
    v_radius numeric;

BEGIN

    v_user_id := auth.uid();


    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    SELECT *
    INTO v_profile
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;


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
    -- Radio
    -- --------------------------------------------------------

    v_radius :=
        COALESCE(
            p_service_radius_km,
            v_profile.service_radius_km,
            8
        );


    IF v_radius < 1 OR v_radius > 100 THEN
        RAISE EXCEPTION 'INVALID_SERVICE_RADIUS';
    END IF;


    -- --------------------------------------------------------
    -- Si quiere ponerse disponible necesitamos ubicación.
    -- --------------------------------------------------------

    IF p_is_available = true THEN

        IF p_latitude IS NULL
           OR p_longitude IS NULL
        THEN
            RAISE EXCEPTION 'LOCATION_REQUIRED';
        END IF;

    END IF;


    IF p_latitude IS NOT NULL
       AND (
            p_latitude < -90
            OR p_latitude > 90
       )
    THEN
        RAISE EXCEPTION 'INVALID_LATITUDE';
    END IF;


    IF p_longitude IS NOT NULL
       AND (
            p_longitude < -180
            OR p_longitude > 180
       )
    THEN
        RAISE EXCEPTION 'INVALID_LONGITUDE';
    END IF;


    IF (
        p_latitude IS NULL
        AND p_longitude IS NOT NULL
    )
    OR (
        p_latitude IS NOT NULL
        AND p_longitude IS NULL
    )
    THEN
        RAISE EXCEPTION 'INCOMPLETE_LOCATION';
    END IF;


    UPDATE public.profiles

    SET
        is_available = p_is_available,

        service_radius_km = v_radius,

        current_latitude =
            COALESCE(
                p_latitude,
                current_latitude
            ),

        current_longitude =
            COALESCE(
                p_longitude,
                current_longitude
            ),

        service_location =
            CASE

                WHEN p_latitude IS NOT NULL
                 AND p_longitude IS NOT NULL

                THEN
                    extensions.ST_SetSRID(
                        extensions.ST_MakePoint(
                            p_longitude,
                            p_latitude
                        ),
                        4326
                    )::extensions.geography

                ELSE service_location

            END,

        location_updated_at =
            CASE

                WHEN p_latitude IS NOT NULL
                 AND p_longitude IS NOT NULL

                THEN now()

                ELSE location_updated_at

            END

    WHERE id = v_user_id

    RETURNING *
    INTO v_profile;


    RETURN v_profile;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.update_professional_presence(
    boolean,
    double precision,
    double precision,
    numeric
)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.update_professional_presence(
    boolean,
    double precision,
    double precision,
    numeric
)
TO authenticated;



-- ============================================================
-- 6. MATCHING GEO
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_nearby_jobs()
RETURNS TABLE (

    job_id uuid,

    title text,

    category text,

    description text,

    address text,

    latitude double precision,

    longitude double precision,

    distance_km numeric,

    created_at timestamptz

)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;

    v_profile public.profiles;

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


    IF v_profile.is_available <> true THEN
        RETURN;
    END IF;


    IF v_profile.service_location IS NULL THEN
        RAISE EXCEPTION 'PROFESSIONAL_LOCATION_REQUIRED';
    END IF;


    RETURN QUERY

    SELECT

        j.id,

        j.title,

        j.category,

        j.description,

        j.address,

        j.latitude,

        j.longitude,

        ROUND(
            (
                extensions.ST_Distance(
                    v_profile.service_location,
                    j.service_location
                )
                / 1000.0
            )::numeric,
            2
        ) AS distance_km,

        j.created_at

    FROM public.jobs j

    WHERE j.status = 'pending'

      AND j.assigned_pro_id IS NULL

      AND j.service_location IS NOT NULL

      AND public.normalize_service_category(
            j.category
          )
          =
          public.normalize_service_category(
            v_profile.category
          )

      AND extensions.ST_DWithin(

            v_profile.service_location,

            j.service_location,

            v_profile.service_radius_km
                * 1000.0

          )

    ORDER BY

        extensions.ST_Distance(
            v_profile.service_location,
            j.service_location
        ),

        j.created_at;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.get_nearby_jobs()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.get_nearby_jobs()
TO authenticated;



-- ============================================================
-- 7. ACCEPT NEARBY JOB
--
-- Sustituirá accept_job() en Flutter.
--
-- Además de seguridad de rol:
-- valida categoría + ubicación + radio.
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_nearby_job(
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

    WHERE id = v_user_id

    FOR UPDATE;


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


    IF v_profile.is_available <> true THEN
        RAISE EXCEPTION 'PROFESSIONAL_NOT_AVAILABLE';
    END IF;


    IF v_profile.service_location IS NULL THEN
        RAISE EXCEPTION 'PROFESSIONAL_LOCATION_REQUIRED';
    END IF;


    SELECT *
    INTO v_job

    FROM public.jobs

    WHERE id = p_job_id

    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.status <> 'pending' THEN
        RAISE EXCEPTION 'JOB_NOT_AVAILABLE';
    END IF;


    IF v_job.assigned_pro_id IS NOT NULL THEN
        RAISE EXCEPTION 'JOB_ALREADY_ASSIGNED';
    END IF;


    IF v_job.service_location IS NULL THEN
        RAISE EXCEPTION 'JOB_LOCATION_REQUIRED';
    END IF;


    -- --------------------------------------------------------
    -- Categoría
    -- --------------------------------------------------------

    IF public.normalize_service_category(
            v_job.category
       )
       <>
       public.normalize_service_category(
            v_profile.category
       )
    THEN

        RAISE EXCEPTION 'CATEGORY_NOT_MATCHED';

    END IF;


    -- --------------------------------------------------------
    -- Radio
    -- --------------------------------------------------------

    IF NOT extensions.ST_DWithin(

        v_profile.service_location,

        v_job.service_location,

        v_profile.service_radius_km
            * 1000.0

    )
    THEN

        RAISE EXCEPTION 'JOB_OUTSIDE_SERVICE_RADIUS';

    END IF;


    -- --------------------------------------------------------
    -- Aceptación
    -- --------------------------------------------------------

    UPDATE public.jobs

    SET
        assigned_pro_id = v_user_id,
        status = 'accepted'

    WHERE id = p_job_id

    RETURNING *
    INTO v_job;


    RETURN v_job;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.accept_nearby_job(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.accept_nearby_job(uuid)
TO authenticated;



-- ============================================================
-- 8. RETIRAR accept_job() DEL CLIENTE
--
-- La dejamos físicamente por compatibilidad,
-- pero Flutter nuevo usará accept_nearby_job().
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.accept_job(uuid)
FROM authenticated, anon, PUBLIC;



-- ============================================================
-- 9. ENDURECER RLS DE JOBS
--
-- El profesional ya NO obtiene todos los pending
-- mediante SELECT directo.
--
-- Los pending se descubren exclusivamente con
-- get_nearby_jobs().
-- ============================================================

DROP POLICY IF EXISTS
jobs_select_for_professional
ON public.jobs;


CREATE POLICY jobs_select_for_professional
ON public.jobs
FOR SELECT
TO authenticated
USING (

    assigned_pro_id = (
        SELECT auth.uid()
    )

    AND EXISTS (

        SELECT 1

        FROM public.profiles p

        WHERE p.id = (
            SELECT auth.uid()
        )

          AND p.role = 'professional'

          AND p.verification_status =
              'approved'

          AND p.account_status =
              'active'

    )

);


COMMIT;