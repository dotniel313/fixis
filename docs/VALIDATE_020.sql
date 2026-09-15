-- FIXIS PRO v1.9.1 — VALIDATE MIGRATION 020 (READ ONLY)

-- 1. Admin policies
SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd
FROM pg_policies
WHERE schemaname IN ('public', 'storage')
  AND policyname IN (
    'payments_select_admin',
    'payment_evidence_select_admin',
    'payment_allocations_select_admin',
    'payment_reconciliation_select_admin',
    'payment_evidence_storage_select_admin'
  )
ORDER BY schemaname, tablename, policyname;

-- Expected: 5 rows.

-- 2. Grants for admin wrappers
SELECT
    routine_name,
    grantee,
    privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN (
    'admin_verify_bank_transfer',
    'admin_reject_bank_transfer',
    'verify_bank_transfer_trusted',
    'reject_bank_transfer_trusted'
  )
ORDER BY routine_name, grantee;

-- Expected:
-- admin_* -> authenticated (+ postgres/service_role may appear)
-- *_trusted -> NOT authenticated.

-- 3. Confirm roles constraint still includes admin
SELECT
    conname,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.profiles'::regclass
  AND conname = 'profiles_role_check';

-- 4. Reconciliation table readable through RLS by authenticated,
-- but no write privileges.
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'payment_reconciliation'
  AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, privilege_type;
