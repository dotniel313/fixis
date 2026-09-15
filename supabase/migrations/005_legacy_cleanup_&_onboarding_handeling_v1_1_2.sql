BEGIN;

-- ============================================================
-- FIXIS PRO v1.1.2
-- MIGRATION 005
-- LEGACY CLEANUP & ONBOARDING HARDENING
-- ============================================================


-- ============================================================
-- 1. ELIMINAR TRIGGER FUNCTION LEGACY
--
-- No tiene ningún trigger asociado actualmente.
-- ============================================================

DROP FUNCTION IF EXISTS public.handle_new_user();


-- ============================================================
-- 2. MANTENER approve_professional POR COMPATIBILIDAD,
-- PERO NO EXPONERLA A CLIENTES.
--
-- No la borramos todavía por si algún panel externo/admin
-- antiguo todavía depende de ella.
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.approve_professional(uuid, text)
FROM PUBLIC;

REVOKE EXECUTE
ON FUNCTION public.approve_professional(uuid, text)
FROM anon;

REVOKE EXECUTE
ON FUNCTION public.approve_professional(uuid, text)
FROM authenticated;


-- ============================================================
-- 3. ACTUALIZAR handle_new_pro_user()
--
-- Un usuario aprobado desde professionals_pending debe
-- convertirse explícitamente en professional/approved/active.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_pro_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    pending_data record;
BEGIN

    -- --------------------------------------------------------
    -- Buscar una postulación aprobada con el mismo email
    -- --------------------------------------------------------

    SELECT *
    INTO pending_data
    FROM public.professionals_pending
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(NEW.email))
      AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;


    -- --------------------------------------------------------
    -- PROFESIONAL APROBADO
    -- --------------------------------------------------------

    IF FOUND THEN

        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            phone,
            category,
            city,
            experience,
            bank,
            account_type,
            account_number,
            role,
            verification_status,
            account_status
        )
        VALUES (
            NEW.id,
            NEW.email,
            pending_data.fullname,
            pending_data.phone,
            pending_data.category,
            pending_data.city,
            pending_data.experience,
            pending_data.bank,
            pending_data.account_type,
            pending_data.account_number,
            'professional',
            'approved',
            'active'
        )
        ON CONFLICT (id)
        DO UPDATE SET
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


    -- --------------------------------------------------------
    -- USUARIO SIN POSTULACIÓN APROBADA
    -- --------------------------------------------------------
    ELSE

        INSERT INTO public.profiles (
            id,
            email,
            full_name,
            role,
            verification_status,
            account_status
        )
        VALUES (
            NEW.id,
            NEW.email,
            'Usuario No Autorizado',
            'customer',
            'pending',
            'active'
        )
        ON CONFLICT (id)
        DO NOTHING;

    END IF;


    RETURN NEW;

END;
$$;


-- ============================================================
-- 4. LA FUNCIÓN ES SOLO PARA EL TRIGGER.
-- No debe ser invocable desde Flutter.
-- ============================================================

REVOKE EXECUTE
ON FUNCTION public.handle_new_pro_user()
FROM PUBLIC, anon, authenticated;


COMMIT;