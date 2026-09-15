BEGIN;

-- ============================================================
-- FIXIS PRO v1.8.3
-- MIGRATION 016
-- FIXIS LIVE FOUNDATION
-- ============================================================


-- ============================================================
-- 1. AMPLIAR STATE MACHINE
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

        -- FIXIS LIVE
        'en_route',
        'arrived',

        'in_progress',
        'work_completed',
        'customer_approved',

        -- legacy
        'completed',

        'cancelled'
    )
);


-- ============================================================
-- 2. TABLA LIVE LOCATION
--
-- Una fila viva por job.
-- No guardamos historial GPS infinito.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_live_locations (

    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    professional_id uuid NOT NULL,

    job_id uuid NOT NULL UNIQUE,

    latitude double precision NOT NULL,
    longitude double precision NOT NULL,

    location extensions.geography(Point, 4326) NOT NULL,

    heading double precision,
    speed double precision,
    accuracy double precision,

    sharing_active boolean NOT NULL DEFAULT true,

    started_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),

    updated_at timestamptz NOT NULL
        DEFAULT timezone('utc', now()),


    CONSTRAINT live_location_professional_fk
    FOREIGN KEY (professional_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE,


    CONSTRAINT live_location_job_fk
    FOREIGN KEY (job_id)
    REFERENCES public.jobs(id)
    ON DELETE CASCADE,


    CONSTRAINT live_location_latitude_check
    CHECK (
        latitude >= -90
        AND latitude <= 90
    ),


    CONSTRAINT live_location_longitude_check
    CHECK (
        longitude >= -180
        AND longitude <= 180
    ),


    CONSTRAINT live_location_heading_check
    CHECK (
        heading IS NULL
        OR (
            heading >= 0
            AND heading <= 360
        )
    ),


    CONSTRAINT live_location_speed_check
    CHECK (
        speed IS NULL
        OR speed >= 0
    ),


    CONSTRAINT live_location_accuracy_check
    CHECK (
        accuracy IS NULL
        OR accuracy >= 0
    )
);


CREATE INDEX IF NOT EXISTS
idx_live_locations_professional
ON public.professional_live_locations(
    professional_id
);


CREATE INDEX IF NOT EXISTS
idx_live_locations_location
ON public.professional_live_locations
USING GIST(location);


CREATE INDEX IF NOT EXISTS
idx_live_locations_active
ON public.professional_live_locations(
    sharing_active
)
WHERE sharing_active = true;


-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE public.professional_live_locations
ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------
-- FIXI puede LEER su propia ubicación live.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS
live_location_select_professional
ON public.professional_live_locations;


CREATE POLICY live_location_select_professional
ON public.professional_live_locations
FOR SELECT
TO authenticated
USING (
    professional_id = (
        SELECT auth.uid()
    )
);


-- ------------------------------------------------------------
-- CLIENTE puede leer ubicación únicamente del FIXI
-- correspondiente a SU job.
-- ------------------------------------------------------------

DROP POLICY IF EXISTS
live_location_select_customer
ON public.professional_live_locations;


CREATE POLICY live_location_select_customer
ON public.professional_live_locations
FOR SELECT
TO authenticated
USING (

    EXISTS (

        SELECT 1

        FROM public.jobs j

        WHERE j.id =
            professional_live_locations.job_id

          AND j.client_id = (
              SELECT auth.uid()
          )

    )

);


-- ============================================================
-- 4. GRANTS
--
-- Flutter:
-- SELECT ✅
-- INSERT/UPDATE/DELETE directo ❌
-- ============================================================

REVOKE ALL
ON public.professional_live_locations
FROM anon;


REVOKE INSERT,
       UPDATE,
       DELETE,
       TRUNCATE,
       REFERENCES,
       TRIGGER
ON public.professional_live_locations
FROM authenticated;


GRANT SELECT
ON public.professional_live_locations
TO authenticated;


-- ============================================================
-- 5. START ROUTE
--
-- authorized → en_route
-- ============================================================

CREATE OR REPLACE FUNCTION public.start_route(
    p_job_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_heading double precision DEFAULT NULL,
    p_speed double precision DEFAULT NULL,
    p_accuracy double precision DEFAULT NULL
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


    IF p_latitude < -90
       OR p_latitude > 90
    THEN
        RAISE EXCEPTION 'INVALID_LATITUDE';
    END IF;


    IF p_longitude < -180
       OR p_longitude > 180
    THEN
        RAISE EXCEPTION 'INVALID_LONGITUDE';
    END IF;


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


    -- Idempotencia
    IF v_job.status = 'en_route' THEN
        RETURN v_job;
    END IF;


    IF v_job.status <> 'authorized' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    IF v_job.client_id IS NULL THEN
        RAISE EXCEPTION 'CLIENT_REQUIRED_FOR_LIVE_TRACKING';
    END IF;


    -- --------------------------------------------------------
    -- Crear / reiniciar ubicación live
    -- --------------------------------------------------------

    INSERT INTO public.professional_live_locations (

        professional_id,
        job_id,

        latitude,
        longitude,
        location,

        heading,
        speed,
        accuracy,

        sharing_active,

        started_at,
        updated_at

    )

    VALUES (

        v_user_id,
        p_job_id,

        p_latitude,
        p_longitude,

        extensions.ST_SetSRID(
            extensions.ST_MakePoint(
                p_longitude,
                p_latitude
            ),
            4326
        )::extensions.geography,

        p_heading,
        p_speed,
        p_accuracy,

        true,

        now(),
        now()

    )

    ON CONFLICT (job_id)

    DO UPDATE SET

        professional_id =
            EXCLUDED.professional_id,

        latitude =
            EXCLUDED.latitude,

        longitude =
            EXCLUDED.longitude,

        location =
            EXCLUDED.location,

        heading =
            EXCLUDED.heading,

        speed =
            EXCLUDED.speed,

        accuracy =
            EXCLUDED.accuracy,

        sharing_active = true,

        started_at = now(),

        updated_at = now();


    UPDATE public.jobs

    SET status = 'en_route'

    WHERE id = p_job_id

    RETURNING *
    INTO v_job;


    RETURN v_job;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.start_route(
    uuid,
    double precision,
    double precision,
    double precision,
    double precision,
    double precision
)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.start_route(
    uuid,
    double precision,
    double precision,
    double precision,
    double precision,
    double precision
)
TO authenticated;


-- ============================================================
-- 6. UPDATE LIVE LOCATION
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_live_location(

    p_job_id uuid,

    p_latitude double precision,
    p_longitude double precision,

    p_heading double precision DEFAULT NULL,
    p_speed double precision DEFAULT NULL,
    p_accuracy double precision DEFAULT NULL

)
RETURNS public.professional_live_locations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE

    v_user_id uuid;
    v_job public.jobs;
    v_location public.professional_live_locations;

BEGIN

    v_user_id := auth.uid();


    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;


    IF p_latitude < -90
       OR p_latitude > 90
    THEN
        RAISE EXCEPTION 'INVALID_LATITUDE';
    END IF;


    IF p_longitude < -180
       OR p_longitude > 180
    THEN
        RAISE EXCEPTION 'INVALID_LONGITUDE';
    END IF;


    SELECT *
    INTO v_job

    FROM public.jobs

    WHERE id = p_job_id;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'JOB_NOT_FOUND';
    END IF;


    IF v_job.assigned_pro_id
       IS DISTINCT FROM v_user_id
    THEN
        RAISE EXCEPTION
        'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
    END IF;


    IF v_job.status <> 'en_route' THEN
        RAISE EXCEPTION 'JOB_NOT_EN_ROUTE';
    END IF;


    UPDATE public.professional_live_locations

    SET
        latitude = p_latitude,

        longitude = p_longitude,

        location =
            extensions.ST_SetSRID(
                extensions.ST_MakePoint(
                    p_longitude,
                    p_latitude
                ),
                4326
            )::extensions.geography,

        heading = p_heading,
        speed = p_speed,
        accuracy = p_accuracy,

        sharing_active = true,

        updated_at = now()

    WHERE job_id = p_job_id

      AND professional_id =
          v_user_id

    RETURNING *
    INTO v_location;


    IF NOT FOUND THEN
        RAISE EXCEPTION 'LIVE_LOCATION_NOT_FOUND';
    END IF;


    RETURN v_location;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.update_live_location(
    uuid,
    double precision,
    double precision,
    double precision,
    double precision,
    double precision
)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.update_live_location(
    uuid,
    double precision,
    double precision,
    double precision,
    double precision,
    double precision
)
TO authenticated;


-- ============================================================
-- 7. MARK ARRIVED
--
-- en_route → arrived
--
-- Detenemos actualizaciones GPS, pero conservamos
-- la última posición para mostrar "FIXI llegó".
-- ============================================================

CREATE OR REPLACE FUNCTION public.mark_arrived(
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


    -- idempotente
    IF v_job.status = 'arrived' THEN
        RETURN v_job;
    END IF;


    IF v_job.status <> 'en_route' THEN
        RAISE EXCEPTION 'INVALID_JOB_STATE';
    END IF;


    UPDATE public.professional_live_locations

    SET
        sharing_active = false,
        updated_at = now()

    WHERE job_id = p_job_id

      AND professional_id =
          v_user_id;


    UPDATE public.jobs

    SET status = 'arrived'

    WHERE id = p_job_id

    RETURNING *
    INTO v_job;


    RETURN v_job;

END;
$$;


REVOKE EXECUTE
ON FUNCTION public.mark_arrived(uuid)
FROM PUBLIC, anon;


GRANT EXECUTE
ON FUNCTION public.mark_arrived(uuid)
TO authenticated;


-- ============================================================
-- 8. ACTUALIZAR start_job()
--
-- NUEVO FLUJO:
-- arrived → in_progress
--
-- Para jobs legacy sin client_id mantenemos
-- authorized → in_progress.
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


    IF v_job.assigned_pro_id
       IS DISTINCT FROM v_user_id
    THEN
        RAISE EXCEPTION
        'JOB_NOT_ASSIGNED_TO_PROFESSIONAL';
    END IF;


    IF v_job.status = 'in_progress' THEN
        RETURN v_job;
    END IF;


    -- --------------------------------------------------------
    -- Jobs nuevos con cliente real:
    -- deben pasar por arrived.
    --
    -- Jobs legacy sin client_id:
    -- permitimos authorized por compatibilidad.
    -- --------------------------------------------------------

    IF v_job.client_id IS NOT NULL THEN

        IF v_job.status <> 'arrived' THEN
            RAISE EXCEPTION 'PROFESSIONAL_MUST_ARRIVE_FIRST';
        END IF;

    ELSE

        IF v_job.status NOT IN (
            'authorized',
            'arrived'
        ) THEN
            RAISE EXCEPTION 'INVALID_JOB_STATE';
        END IF;

    END IF;


    IF v_job.accepted_quote_id IS NULL THEN
        RAISE EXCEPTION 'ACCEPTED_QUOTE_REQUIRED';
    END IF;


    IF NOT EXISTS (

        SELECT 1

        FROM public.job_financial_snapshots fs

        WHERE fs.job_id = p_job_id

          AND fs.quote_id =
              v_job.accepted_quote_id

    ) THEN

        RAISE EXCEPTION
        'FINANCIAL_SNAPSHOT_REQUIRED';

    END IF;


    UPDATE public.professional_live_locations

    SET
        sharing_active = false,
        updated_at = now()

    WHERE job_id = p_job_id;


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


-- ============================================================
-- 9. REALTIME
--
-- Añadir tabla únicamente si aún no está publicada.
-- ============================================================

DO $$
BEGIN

    IF NOT EXISTS (

        SELECT 1

        FROM pg_publication_tables

        WHERE pubname =
            'supabase_realtime'

          AND schemaname =
            'public'

          AND tablename =
            'professional_live_locations'

    ) THEN

        ALTER PUBLICATION supabase_realtime
        ADD TABLE public.professional_live_locations;

    END IF;

END;
$$;


COMMIT;