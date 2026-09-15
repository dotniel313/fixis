-- FIXIS PRO v1.9.0 — VALIDATE 019 (READ ONLY)

SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'payment_bank_accounts';

SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'payment_bank_accounts';

SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'payment_bank_accounts'
  AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, privilege_type;

SELECT
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id = 'payment-evidence';

SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname LIKE 'payment_evidence_storage_%'
ORDER BY policyname;
