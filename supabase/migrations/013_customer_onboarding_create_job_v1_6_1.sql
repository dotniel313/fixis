BEGIN;

-- FIXIS PRO v1.6.1 - Customer onboarding + create_job

CREATE OR REPLACE FUNCTION public.handle_new_pro_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    pending_data record;
    v_customer_name text;
    v_customer_phone text;
BEGIN
    SELECT * INTO pending_data
    FROM public.professionals_pending
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(NEW.email))
      AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
        INSERT INTO public.profiles (
            id, email, full_name, phone, category, city, experience,
            bank, account_type, account_number,
            role, verification_status, account_status
        )
        VALUES (
            NEW.id, NEW.email, pending_data.fullname, pending_data.phone,
            pending_data.category, pending_data.city, pending_data.experience,
            pending_data.bank, pending_data.account_type, pending_data.account_number,
            'professional', 'approved', 'active'
        )
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            full_name = EXCLUDED.full_name,
            phone = EXCLUDED.phone,
            category = EXCLUDED.category,
            city = EXCLUDED.city,
            experience = EXCLUDED.experience,
            bank = EXCLUDED.bank,
            account_type = EXCLUDED.account_type,
            account_number = EXCLUDED.account_number,
            role = 'professional',
            verification_status = 'approved',
            account_status = 'active';

        UPDATE public.professionals_pending
        SET status = 'transferred'
        WHERE id = pending_data.id;
    ELSE
        v_customer_name := NULLIF(TRIM(COALESCE(
            NEW.raw_user_meta_data ->> 'full_name',
            NEW.raw_user_meta_data ->> 'name',
            ''
        )), '');

        v_customer_phone := NULLIF(TRIM(COALESCE(
            NEW.raw_user_meta_data ->> 'phone',
            NEW.phone,
            ''
        )), '');

        INSERT INTO public.profiles (
            id, email, full_name, phone,
            role, verification_status, account_status
        )
        VALUES (
            NEW.id, NEW.email,
            COALESCE(v_customer_name, 'Cliente FIXIS'),
            v_customer_phone,
            'customer', 'pending', 'active'
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_new_pro_user()
FROM PUBLIC, anon, authenticated;

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
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'PROFILE_NOT_FOUND'; END IF;
    IF v_profile.role <> 'customer' THEN RAISE EXCEPTION 'NOT_A_CUSTOMER'; END IF;
    IF v_profile.account_status <> 'active' THEN RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE'; END IF;

    v_title := NULLIF(TRIM(p_title), '');
    v_category := NULLIF(TRIM(p_category), '');
    v_address := NULLIF(TRIM(p_address), '');
    v_description := NULLIF(TRIM(p_description), '');

    IF v_title IS NULL THEN RAISE EXCEPTION 'TITLE_REQUIRED'; END IF;
    IF v_category IS NULL THEN RAISE EXCEPTION 'CATEGORY_REQUIRED'; END IF;
    IF v_address IS NULL THEN RAISE EXCEPTION 'ADDRESS_REQUIRED'; END IF;
    IF LENGTH(v_title) > 150 THEN RAISE EXCEPTION 'TITLE_TOO_LONG'; END IF;
    IF LENGTH(v_category) > 100 THEN RAISE EXCEPTION 'CATEGORY_TOO_LONG'; END IF;
    IF LENGTH(v_address) > 300 THEN RAISE EXCEPTION 'ADDRESS_TOO_LONG'; END IF;
    IF v_description IS NOT NULL AND LENGTH(v_description) > 2000 THEN
        RAISE EXCEPTION 'DESCRIPTION_TOO_LONG';
    END IF;
    IF p_latitude IS NOT NULL AND (p_latitude < -90 OR p_latitude > 90) THEN
        RAISE EXCEPTION 'INVALID_LATITUDE';
    END IF;
    IF p_longitude IS NOT NULL AND (p_longitude < -180 OR p_longitude > 180) THEN
        RAISE EXCEPTION 'INVALID_LONGITUDE';
    END IF;
    IF (p_latitude IS NULL AND p_longitude IS NOT NULL)
       OR (p_latitude IS NOT NULL AND p_longitude IS NULL) THEN
        RAISE EXCEPTION 'INCOMPLETE_LOCATION';
    END IF;

    INSERT INTO public.jobs (
        client_id, client_name, category, title, description, address,
        latitude, longitude, status, assigned_pro_id, accepted_quote_id
    )
    VALUES (
        v_user_id,
        COALESCE(NULLIF(TRIM(v_profile.full_name), ''), 'Cliente FIXIS'),
        v_category, v_title, v_description, v_address,
        p_latitude, p_longitude, 'pending', NULL, NULL
    )
    RETURNING * INTO v_job;

    RETURN v_job;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_job(text,text,text,text,double precision,double precision)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_job(text,text,text,text,double precision,double precision)
TO authenticated;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON public.jobs FROM authenticated;
GRANT SELECT ON public.jobs TO authenticated;

COMMIT;
