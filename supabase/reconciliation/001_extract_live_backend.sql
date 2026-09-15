-- ============================================================
-- FIXIS PRO v1.8.5.2 — BACKEND RECONCILIATION SNAPSHOT
-- Ejecutar en Supabase SQL Editor y guardar TODOS los resultados.
-- Solo lectura. No modifica datos ni esquema.
-- ============================================================

-- A. Extensiones instaladas
SELECT extname, extversion, n.nspname AS schema_name
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY extname;

-- B. Tablas FIXIS visibles
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- C. Columnas de tablas de dominio
SELECT table_name, ordinal_position, column_name, data_type, udt_schema, udt_name,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'profiles','jobs','quotes','commission_rules','job_financial_snapshots',
    'financial_accounts','financial_ledger_entries','settlements','settlement_items',
    'professional_live_locations','expert_gamification','professionals_pending',
    'wallet_transactions'
  )
ORDER BY table_name, ordinal_position;

-- D. Constraints (PK/FK/UNIQUE/CHECK)
SELECT c.conrelid::regclass::text AS table_name,
       c.conname,
       c.contype,
       pg_get_constraintdef(c.oid, true) AS definition
FROM pg_constraint c
WHERE c.connamespace = 'public'::regnamespace
  AND c.conrelid <> 0
ORDER BY table_name, c.conname;

-- E. Índices
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- F. Policies RLS
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- G. Estado RLS por tabla
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY c.relname;

-- H. Funciones/RPC completas
SELECT p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       p.prosecdef AS security_definer,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY p.proname, identity_arguments;

-- I. Triggers no internos
SELECT event_object_table AS table_name,
       trigger_name,
       event_manipulation,
       action_timing,
       action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY table_name, trigger_name, event_manipulation;

-- J. Grants de tablas
SELECT grantee, table_name, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('anon','authenticated','service_role')
ORDER BY table_name, grantee, privilege_type;

-- K. Grants de rutinas
SELECT grantee, routine_name, privilege_type, is_grantable
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
  AND grantee IN ('anon','authenticated','service_role')
ORDER BY routine_name, grantee, privilege_type;

-- L. Supabase Realtime
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;
