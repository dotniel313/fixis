-- ============================================================
-- FIXIS PRO v1.9.0
-- VALIDATION - MIGRATION 018 PAYMENTS FOUNDATION
-- READ ONLY
-- ============================================================

-- 1. Tables
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'payments',
    'payment_evidence',
    'payment_reconciliation',
    'payment_allocations'
  )
ORDER BY tablename;

-- Expected: 4 rows.

-- 2. RLS enabled
SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'payments',
    'payment_evidence',
    'payment_reconciliation',
    'payment_allocations'
  )
ORDER BY c.relname;

-- Expected: all true.

-- 3. Authenticated table privileges
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
    'payments',
    'payment_evidence',
    'payment_reconciliation',
    'payment_allocations'
  )
  AND grantee IN ('anon', 'authenticated')
ORDER BY table_name, grantee, privilege_type;

-- Expected:
-- authenticated SELECT only on payments/payment_evidence/payment_allocations.
-- no direct INSERT/UPDATE/DELETE.
-- no client access to payment_reconciliation.

-- 4. RPC grants
SELECT
    routine_name,
    grantee,
    privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name IN (
    'prepare_job_payment',
    'submit_bank_transfer_evidence',
    'verify_bank_transfer_trusted',
    'reject_bank_transfer_trusted',
    'approve_completed_job',
    'approve_completed_job_trusted'
  )
ORDER BY routine_name, grantee;

-- Expected:
-- prepare_job_payment -> authenticated
-- submit_bank_transfer_evidence -> authenticated
-- verify/reject trusted -> service_role (+ postgres owner may appear)
-- approve_completed_job -> NOT authenticated
-- approve_completed_job_trusted -> service_role (+ postgres owner may appear)

-- 5. Constraints
SELECT
    conrelid::regclass AS table_name,
    conname,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN (
    'public.payments'::regclass,
    'public.payment_evidence'::regclass,
    'public.payment_reconciliation'::regclass,
    'public.payment_allocations'::regclass
)
ORDER BY conrelid::regclass::text, conname;

-- 6. Policies
SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'payments',
    'payment_evidence',
    'payment_reconciliation',
    'payment_allocations'
  )
ORDER BY tablename, policyname;

-- 7. Verify there is no authenticated direct approval bypass
SELECT
    routine_name,
    grantee
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND routine_name = 'approve_completed_job'
ORDER BY grantee;
