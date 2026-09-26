BEGIN;

-- Ratings are tied to a verified customer payment. Neither participant can
-- insert, edit or delete them directly; the RPC derives both identities.
CREATE TABLE IF NOT EXISTS public.job_ratings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id uuid NOT NULL REFERENCES public.jobs(id) ON DELETE RESTRICT,
    reviewer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    reviewed_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    reviewer_role text NOT NULL CHECK (reviewer_role IN ('customer', 'professional')),
    score integer NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment text CHECK (comment IS NULL OR char_length(comment) BETWEEN 1 AND 500),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT job_ratings_once_per_author UNIQUE (job_id, reviewer_id),
    CONSTRAINT job_ratings_distinct_parties CHECK (reviewer_id <> reviewed_id)
);

CREATE INDEX IF NOT EXISTS job_ratings_received_idx
    ON public.job_ratings (reviewed_id, created_at DESC);

ALTER TABLE public.job_ratings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.job_ratings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.job_ratings TO authenticated;

DROP POLICY IF EXISTS job_ratings_read_parties ON public.job_ratings;
CREATE POLICY job_ratings_read_parties ON public.job_ratings
    FOR SELECT TO authenticated
    USING (reviewer_id = (SELECT auth.uid()) OR reviewed_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.submit_job_rating(
    p_job_id uuid,
    p_score integer,
    p_comment text DEFAULT NULL
)
RETURNS public.job_ratings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_payment public.payments%ROWTYPE;
    v_job public.jobs%ROWTYPE;
    v_role text;
    v_reviewer_role text;
    v_reviewed_id uuid;
    v_comment text := nullif(btrim(p_comment), '');
    v_rating public.job_ratings%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;
    IF p_score IS NULL OR p_score NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'INVALID_RATING_SCORE';
    END IF;
    IF v_comment IS NOT NULL AND char_length(v_comment) > 500 THEN
        RAISE EXCEPTION 'RATING_COMMENT_TOO_LONG';
    END IF;

    SELECT role INTO v_role
    FROM public.profiles
    WHERE id = v_user_id AND account_status = 'active';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ACCOUNT_NOT_ACTIVE';
    END IF;

    SELECT * INTO v_payment
    FROM public.payments
    WHERE job_id = p_job_id
    FOR SHARE;
    IF NOT FOUND OR v_payment.status <> 'paid' THEN
        RAISE EXCEPTION 'PAYMENT_NOT_CONFIRMED';
    END IF;

    SELECT * INTO v_job FROM public.jobs WHERE id = p_job_id;
    IF NOT FOUND OR v_job.status <> 'customer_approved'
       OR v_job.client_id IS DISTINCT FROM v_payment.customer_id
       OR v_job.assigned_pro_id IS DISTINCT FROM v_payment.professional_id THEN
        RAISE EXCEPTION 'JOB_NOT_ELIGIBLE_FOR_RATING';
    END IF;

    IF v_user_id = v_payment.customer_id AND v_role = 'customer' THEN
        v_reviewer_role := 'customer';
        v_reviewed_id := v_payment.professional_id;
    ELSIF v_user_id = v_payment.professional_id AND v_role = 'professional' THEN
        v_reviewer_role := 'professional';
        v_reviewed_id := v_payment.customer_id;
    ELSE
        RAISE EXCEPTION 'RATING_NOT_ALLOWED';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.job_ratings
        WHERE job_id = p_job_id AND reviewer_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'RATING_ALREADY_SUBMITTED';
    END IF;

    INSERT INTO public.job_ratings (
        job_id, reviewer_id, reviewed_id, reviewer_role, score, comment
    ) VALUES (
        p_job_id, v_user_id, v_reviewed_id, v_reviewer_role, p_score, v_comment
    ) RETURNING * INTO v_rating;

    RETURN v_rating;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_job_rating(uuid, integer, text)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_job_rating(uuid, integer, text)
    TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_rating_summary()
RETURNS TABLE (ratings_received bigint, average_score numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;
    RETURN QUERY
    SELECT count(*)::bigint, round(avg(r.score)::numeric, 2)
    FROM public.job_ratings r
    WHERE r.reviewed_id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_rating_summary()
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_rating_summary()
    TO authenticated;

-- Loyalty is earned by actual paid services. No monetary points, discounts,
-- coupon balances or invented tiers are issued by this release.
CREATE OR REPLACE FUNCTION public.get_customer_loyalty_summary()
RETURNS TABLE (
    paid_services bigint,
    categories_used bigint,
    last_paid_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = v_user_id AND role = 'customer' AND account_status = 'active'
    ) THEN
        RAISE EXCEPTION 'CUSTOMER_ACCOUNT_REQUIRED';
    END IF;

    RETURN QUERY
    SELECT count(*)::bigint,
           count(DISTINCT j.category)::bigint,
           max(p.paid_at)
    FROM public.payments p
    JOIN public.jobs j ON j.id = p.job_id
    WHERE p.customer_id = v_user_id
      AND p.status = 'paid'
      AND j.status = 'customer_approved';
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_loyalty_summary()
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_loyalty_summary()
    TO authenticated;

COMMIT;
