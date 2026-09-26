-- FIXIS: prueba de aislamiento de identidad/calificaciones (solo lecturas de datos).
-- Ejecutar toda esta unica sentencia DO desde Supabase SQL Editor.
-- El editor puede separar sentencias y perder SET LOCAL entre consultas.
-- Un "Success. No rows returned" significa que TODAS las condiciones pasaron.
-- Si falla, el error QA_* identifica exactamente la comprobacion fallida.
DO $$
DECLARE
    v_third_party uuid;
    v_job_id uuid := '9a051626-61c8-466a-90d8-71bc87304f1f'::uuid;
BEGIN
    -- La eleccion de la cuenta ocurre antes de adoptar el rol autenticado.
    SELECT p.id INTO v_third_party
    FROM public.profiles p
    JOIN public.jobs j ON j.id = v_job_id
    WHERE p.account_status = 'active'
      AND p.id IS DISTINCT FROM j.client_id
      AND p.id IS DISTINCT FROM j.assigned_pro_id
    ORDER BY CASE WHEN p.role = 'admin' THEN 0 ELSE 1 END, p.id
    LIMIT 1;

    IF v_third_party IS NULL THEN
        RAISE EXCEPTION 'QA_REQUIRES_ACTIVE_THIRD_PARTY_ACCOUNT';
    END IF;

    PERFORM set_config('request.jwt.claim.sub', v_third_party::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';

    IF current_user <> 'authenticated' OR auth.uid() IS DISTINCT FROM v_third_party THEN
        RAISE EXCEPTION 'QA_IMPERSONATION_FAILED';
    END IF;

    IF EXISTS (SELECT 1 FROM public.get_rating_recipient(v_job_id)) THEN
        RAISE EXCEPTION 'QA_THIRD_PARTY_CAN_SEE_RECIPIENT';
    END IF;

    IF EXISTS (SELECT 1 FROM public.job_ratings WHERE job_id = v_job_id) THEN
        RAISE EXCEPTION 'QA_THIRD_PARTY_CAN_SEE_RATINGS';
    END IF;

    RAISE NOTICE 'QA_OK: tercero autenticado sin acceso a identidad ni calificaciones';
END;
$$;
