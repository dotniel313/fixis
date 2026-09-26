-- Run after migration 035 in Supabase SQL Editor (one complete execution).
-- Output: all three columns true. This script changes no database rows.
BEGIN TRANSACTION READ ONLY;

SELECT
    to_regprocedure('public.get_my_received_reviews()') IS NOT NULL
        AS received_reviews_rpc,
    NOT has_function_privilege('anon', 'public.get_my_received_reviews()', 'EXECUTE')
        AS anon_cannot_list_reviews,
    has_function_privilege('authenticated', 'public.get_my_received_reviews()', 'EXECUTE')
        AS authenticated_can_list_own_reviews;

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
        SELECT 1 FROM public.get_my_received_reviews()
        WHERE job_id = '9a051626-61c8-466a-90d8-71bc87304f1f'::uuid
    ) AS tercero_no_ve_reseña_ajena;

ROLLBACK;
