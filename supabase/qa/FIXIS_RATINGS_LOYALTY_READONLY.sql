-- Ejecutar en Supabase SQL Editor DESPUES de aplicar la migracion 033.
-- Todas las consultas son de solo lectura. No devuelve nombres ni correos.

SELECT
    to_regclass('public.job_ratings') IS NOT NULL AS ratings_table,
    to_regprocedure('public.submit_job_rating(uuid,integer,text)') IS NOT NULL
        AS submit_rating_rpc,
    to_regprocedure('public.get_my_rating_summary()') IS NOT NULL
        AS rating_summary_rpc,
    to_regprocedure('public.get_customer_loyalty_summary()') IS NOT NULL
        AS loyalty_summary_rpc,
    has_table_privilege('anon', 'public.job_ratings', 'INSERT') = false
        AS anon_cannot_insert,
    has_table_privilege('authenticated', 'public.job_ratings', 'INSERT') = false
        AS client_cannot_insert_directly,
    has_function_privilege('anon',
        'public.submit_job_rating(uuid,integer,text)', 'EXECUTE') = false
        AS anon_cannot_rate;

-- Tras pruebas de los dos roles, ambos contadores deben ser cero.
SELECT
    (SELECT count(*)
     FROM public.job_ratings r
     JOIN public.jobs j ON j.id = r.job_id
     JOIN public.payments p ON p.job_id = j.id
     WHERE p.verified_at IS NULL OR j.status <> 'customer_approved'
        OR (r.reviewer_role = 'customer'
            AND (r.reviewer_id IS DISTINCT FROM p.customer_id
                OR r.reviewed_id IS DISTINCT FROM p.professional_id))
        OR (r.reviewer_role = 'professional'
            AND (r.reviewer_id IS DISTINCT FROM p.professional_id
                OR r.reviewed_id IS DISTINCT FROM p.customer_id)))
        AS ratings_inconsistent,
    (SELECT count(*) FROM (
        SELECT job_id, reviewer_id
        FROM public.job_ratings
        GROUP BY job_id, reviewer_id
        HAVING count(*) > 1
    ) duplicated) AS duplicate_ratings;

-- Despues de aplicar 034: nombre/foto disponibles solo mediante RPC para
-- participantes autenticados de un servicio pagado.
SELECT
    to_regprocedure('public.get_rating_recipient(uuid)') IS NOT NULL
        AS rating_recipient_rpc,
    has_function_privilege('anon', 'public.get_rating_recipient(uuid)', 'EXECUTE') = false
        AS anon_cannot_get_recipient,
    has_function_privilege('authenticated', 'public.get_rating_recipient(uuid)', 'EXECUTE') = true
        AS participant_can_request_recipient;
