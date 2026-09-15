BEGIN;

-- ============================================================
-- FIXIS PRO v1.8.2
-- MIGRATION 015
-- FIX JOB GEO CREATION
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_job(
    p_title text,
    p_category text,
    p_address text,
    p_description text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL
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
    v_title text;
    v_category text;
    v_address text;
    v_description text;
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

    v_title := NULLIF(TRIM(p_title), '');
    v_category := NULLIF(TRIM(p_category), '');
    v_address := NULLIF(TRIM(p_address), '');
    v_description := NULLIF(TRIM(p_description), '');

    IF v_title IS NULL THEN
        RAISE EXCEPTION 'TITLE_REQUIRED';
    END IF;

    IF v_category IS NULL THEN
        RAISE EXCEPTION 'CATEGORY_REQUIRED';
    END IF;

    IF v_address IS NULL THEN
        RAISE EXCEPTION 'ADDRESS_REQUIRED';
    END IF;

    IF LENGTH(v_title) > 150 THEN
        RAISE EXCEPTION 'TITLE_TOO_LONG';
    END IF;

    IF LENGTH(v_category) > 100 THEN
        RAISE EXCEPTION 'CATEGORY_TOO_LONG';
    END IF;

    IF LENGTH(v_address) > 300 THEN
        RAISE EXCEPTION 'ADDRESS_TOO_LONG';
    END IF;

    IF v_description IS NOT NULL AND LENGTH(v_description) > 2000 THEN
        RAISE EXCEPTION 'DESCRIPTION_TOO_LONG';
    END IF;

    -- v1.8.2: el matching geográfico exige coordenadas reales.
    IF p_latitude IS NULL OR p_longitude IS NULL THEN
        RAISE EXCEPTION 'LOCATION_REQUIRED';
    END IF;

    IF p_latitude < -90 OR p_latitude > 90 THEN
        RAISE EXCEPTION 'INVALID_LATITUDE';
    END IF;

    IF p_longitude < -180 OR p_longitude > 180 THEN
        RAISE EXCEPTION 'INVALID_LONGITUDE';
    END IF;

    INSERT INTO public.jobs (
        client_id,
        client_name,
        category,
        title,
        description,
        address,
        latitude,
        longitude,
        service_location,
        status,
        assigned_pro_id,
        accepted_quote_id
    )
    VALUES (
        v_user_id,
        COALESCE(NULLIF(TRIM(v_profile.full_name), ''), 'Cliente FIXIS'),
        v_category,
        v_title,
        v_description,
        v_address,
        p_latitude,
        p_longitude,
        extensions.ST_SetSRID(
            extensions.ST_MakePoint(p_longitude, p_latitude),
            4326
        )::extensions.geography,
        'pending',
        NULL,
        NULL
    )
    RETURNING * INTO v_job;

    RETURN v_job;
END;
$$;

REVOKE EXECUTE
ON FUNCTION public.create_job(text, text, text, text, double precision, double precision)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.create_job(text, text, text, text, double precision, double precision)
TO authenticated;

COMMIT;
