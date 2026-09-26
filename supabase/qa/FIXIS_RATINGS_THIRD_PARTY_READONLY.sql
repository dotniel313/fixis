-- FIXIS: solo lectura. Ejecutar TODO el bloque en una sola corrida
-- desde Supabase SQL Editor. Los ajustes de rol/JWT duran esta transaccion.
-- Servicio pagado con calificacion bilateral confirmada: 9a051626...
BEGIN TRANSACTION READ ONLY;

DO $$
DECLARE
    v_third_party uuid;
BEGIN
    SELECT p.id INTO v_third_party
    FROM public.profiles p
    JOIN public.jobs j
      ON j.id = '9a051626-61c8-466a-90d8-71bc87304f1f'::uuid
    WHERE p.account_status = 'active'
      AND p.id IS DISTINCT FROM j.client_id
      AND p.id IS DISTINCT FROM j.assigned_pro_id
    ORDER BY CASE WHEN p.role = 'admin' THEN 0 ELSE 1 END, p.id
    LIMIT 1;

    IF v_third_party IS NULL THEN
        RAISE EXCEPTION 'QA_REQUIRES_ACTIVE_THIRD_PARTY_ACCOUNT';
    END IF;
    PERFORM set_config('request.jwt.claim.sub', v_third_party::text, true);
END;
$$;

SET LOCAL ROLE authenticated;

SELECT
    auth.uid() IS NOT NULL AS tercero_simulado,
    NOT EXISTS (
        SELECT 1
        FROM public.get_rating_recipient(
          '9a051626-61c8-466a-90d8-71bc87304f1f'::uuid)
    ) AS tercero_no_ve_identidad,
    NOT EXISTS (
        SELECT 1 FROM public.job_ratings
        WHERE job_id = '9a051626-61c8-466a-90d8-71bc87304f1f'::uuid
    ) AS tercero_no_ve_calificaciones;

ROLLBACK;
