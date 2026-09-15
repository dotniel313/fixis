-- 1. CHECK must include transferred
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.professionals_pending'::regclass
  AND conname = 'professionals_pending_status_check';

-- 2. delete_user_account grants: anon must be absent
SELECT grantee, routine_name, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name = 'delete_user_account'
ORDER BY grantee;

-- 3. Redundant FK names must be gone
SELECT conrelid::regclass AS table_name, conname,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conname IN (
  'profiles_id_fkey',
  'profiles_auth_user_fk',
  'expert_gamification_pro_id_fkey',
  'expert_gamification_profile_fk',
  'wallet_transactions_pro_id_fkey',
  'wallet_transactions_profile_fk'
)
ORDER BY 1, 2;

-- 4. Client roles must not execute dormant legacy completion
SELECT grantee, routine_name, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN ('handle_completed_job', 'approve_professional')
ORDER BY routine_name, grantee;

-- 5. Realtime must remain unchanged
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;
