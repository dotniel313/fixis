BEGIN;

-- ============================================================
-- FIXIS PRO v1.8.5.2
-- Migration 017 — Backend Stabilization
-- Reconciled against live Supabase schema (2026-09-10)
-- ============================================================

-- ------------------------------------------------------------
-- STAB-DB-001
-- professionals_pending: handle_new_pro_user() uses 'transferred'
-- but the live CHECK only allows pending/approved/rejected.
-- ------------------------------------------------------------
ALTER TABLE public.professionals_pending
DROP CONSTRAINT IF EXISTS professionals_pending_status_check;

ALTER TABLE public.professionals_pending
ADD CONSTRAINT professionals_pending_status_check
CHECK (status = ANY (ARRAY[
  'pending'::text,
  'approved'::text,
  'rejected'::text,
  'transferred'::text
]));

-- ------------------------------------------------------------
-- STAB-SEC-001
-- delete_user_account() must never be executable by anon/PUBLIC.
-- Keep self-delete available only to authenticated/service_role.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  DELETE FROM auth.users
  WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO service_role;

-- ------------------------------------------------------------
-- STAB-DB-002
-- Remove redundant historical foreign keys. The remaining FKs
-- point to public.profiles and preserve the intended delete rules.
-- ------------------------------------------------------------
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;
-- Keep profiles_auth_user_fk -> auth.users(id) ON DELETE CASCADE.

ALTER TABLE public.expert_gamification
DROP CONSTRAINT IF EXISTS expert_gamification_pro_id_fkey;
-- Keep expert_gamification_profile_fk -> profiles(id) ON DELETE CASCADE.

ALTER TABLE public.wallet_transactions
DROP CONSTRAINT IF EXISTS wallet_transactions_pro_id_fkey;
-- Keep wallet_transactions_profile_fk -> profiles(id) ON DELETE RESTRICT.

-- ------------------------------------------------------------
-- STAB-LEG-001
-- Legacy completion function is dormant (no trigger currently
-- attached in the live audit). Prevent accidental client access.
-- We intentionally do NOT drop it yet; historical DB reconstruction
-- is handled separately.
-- ------------------------------------------------------------
REVOKE ALL ON FUNCTION public.handle_completed_job() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_completed_job() FROM anon;
REVOKE ALL ON FUNCTION public.handle_completed_job() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.handle_completed_job() TO service_role;

-- Legacy professional approval remains service_role-only.
REVOKE ALL ON FUNCTION public.approve_professional(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_professional(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.approve_professional(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_professional(uuid, text) TO service_role;

COMMIT;
