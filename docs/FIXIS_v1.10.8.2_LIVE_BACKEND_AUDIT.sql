-- FIXIS PRO v1.10.8.2 — PRE-MIGRATION LIVE BACKEND AUDIT
-- SOLO LECTURA. No modifica tablas, funciones, políticas ni datos.
-- Ejecutar completo en Supabase SQL Editor y copiar el resultado.

-- ============================================================
-- A. JOBS: columnas reales y tipos
-- ============================================================
select
  'A_jobs_columns' as section,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'jobs'
order by c.ordinal_position;

-- ============================================================
-- B. QUOTES: columnas reales y restricciones
-- ============================================================
select
  'B_quotes_columns' as section,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'quotes'
order by c.ordinal_position;

select
  'B2_quotes_constraints' as section,
  con.conname as constraint_name,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'quotes'
order by con.conname;

-- ============================================================
-- C. Funciones críticas: firma + definición LIVE
-- ============================================================
select
  'C_functions' as section,
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'create_job',
    'create_quote',
    'submit_quote',
    'accept_quote_customer',
    'start_route',
    'update_live_location',
    'mark_arrived',
    'start_job',
    'finish_job'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- ============================================================
-- D. RLS y policies de tablas que tocaremos
-- ============================================================
select
  'D_rls' as section,
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'jobs',
    'quotes',
    'job_financial_snapshots',
    'professional_live_locations'
  )
order by c.relname;

select
  'D2_policies' as section,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'jobs',
    'quotes',
    'job_financial_snapshots',
    'professional_live_locations'
  )
order by tablename, policyname;

-- ============================================================
-- E. Storage existente (para fotos/evidencias)
-- ============================================================
select
  'E_storage_buckets' as section,
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
order by id;

select
  'E2_storage_policies' as section,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;

-- ============================================================
-- F. Tablas que podrían existir para adjuntos/agenda/legal
-- ============================================================
select
  'F_candidate_tables' as section,
  table_schema,
  table_name
from information_schema.tables
where table_schema = 'public'
  and (
    table_name ilike '%attachment%' or
    table_name ilike '%evidence%' or
    table_name ilike '%schedule%' or
    table_name ilike '%appointment%' or
    table_name ilike '%legal%' or
    table_name ilike '%consent%' or
    table_name ilike '%terms%' or
    table_name ilike '%acceptance%'
  )
order by table_name;

-- ============================================================
-- G. Grants de funciones críticas
-- ============================================================
select
  'G_function_grants' as section,
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'create_job',
    'create_quote',
    'submit_quote',
    'accept_quote_customer',
    'start_route',
    'update_live_location',
    'mark_arrived',
    'start_job',
    'finish_job'
  )
order by routine_name, grantee;
