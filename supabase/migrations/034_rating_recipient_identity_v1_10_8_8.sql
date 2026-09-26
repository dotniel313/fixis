BEGIN;

-- Reveal only the other participant's display identity for a paid job.
-- profiles remains restricted to its owner by RLS.
CREATE OR REPLACE FUNCTION public.get_rating_recipient(p_job_id uuid)
RETURNS TABLE (recipient_name text, recipient_avatar_url text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        COALESCE(NULLIF(btrim(recipient.full_name), ''),
                 CASE WHEN me.id = p.customer_id THEN 'Profesional FIXIS'
                      ELSE 'Cliente FIXIS' END)::text,
        recipient.avatar_url::text
    FROM public.payments p
    JOIN public.jobs j ON j.id = p.job_id
    JOIN public.profiles me ON me.id = (SELECT auth.uid())
    JOIN public.profiles recipient
      ON recipient.id = CASE WHEN me.id = p.customer_id
                           THEN p.professional_id ELSE p.customer_id END
    WHERE p_job_id IS NOT NULL
      AND p.job_id = p_job_id
      AND p.status = 'paid'
      AND j.status = 'customer_approved'
      AND j.client_id = p.customer_id
      AND j.assigned_pro_id = p.professional_id
      AND me.account_status = 'active'
      AND ((me.id = p.customer_id AND me.role = 'customer')
           OR (me.id = p.professional_id AND me.role = 'professional'))
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_rating_recipient(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_rating_recipient(uuid) TO authenticated;

COMMIT;
