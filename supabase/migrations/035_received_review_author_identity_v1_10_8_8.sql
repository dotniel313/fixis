BEGIN;

-- Only the recipient may list the identity of authors who reviewed them.
-- Batch the author name/photo with the review to avoid one RPC per card.
CREATE OR REPLACE FUNCTION public.get_my_received_reviews()
RETURNS TABLE (
    job_id uuid,
    job_title text,
    score integer,
    comment text,
    reviewer_role text,
    reviewer_name text,
    reviewer_avatar_url text,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        r.job_id,
        j.title::text,
        r.score,
        r.comment,
        r.reviewer_role,
        COALESCE(
            NULLIF(btrim(author.full_name), ''),
            CASE WHEN r.reviewer_role = 'customer'
                 THEN 'Cliente FIXIS' ELSE 'Profesional FIXIS' END
        )::text,
        author.avatar_url::text,
        r.created_at
    FROM public.job_ratings r
    JOIN public.jobs j ON j.id = r.job_id
    JOIN public.profiles author ON author.id = r.reviewer_id
    WHERE r.reviewed_id = (SELECT auth.uid())
      AND EXISTS (
          SELECT 1 FROM public.profiles me
          WHERE me.id = (SELECT auth.uid())
            AND me.account_status = 'active'
      )
    ORDER BY r.created_at DESC
    LIMIT 50;
$$;

REVOKE ALL ON FUNCTION public.get_my_received_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_received_reviews() TO authenticated;

COMMIT;
