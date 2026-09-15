-- FIXIS PRO v1.10.8.2 — LIVE BACKEND AUDIT / FASE 2
-- SOLO LECTURA. Completa los datos faltantes antes de diseñar la migración.

-- 1) QUOTES: columnas reales
select
  'Q1_quotes_columns' as section,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'quotes'
order by ordinal_position;

-- 2) JOBS: constraints (incluye status si existe CHECK)
select
  'Q2_jobs_constraints' as section,
  con.conname as constraint_name,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'jobs'
order by con.conname;

-- 3) FINANCIAL SNAPSHOT: columnas/constraints
select
  'Q3_snapshot_columns' as section,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'job_financial_snapshots'
order by ordinal_position;

select
  'Q4_snapshot_constraints' as section,
  con.conname as constraint_name,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public' and rel.relname = 'job_financial_snapshots'
order by con.conname;

-- 4) MOTOR ECONÓMICO REAL
select
  'Q5_financial_functions' as section,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('accept_quote_trusted','customer_approve_job')
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- 5) RLS real
select
  'Q6_rls' as section,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('jobs','quotes','job_financial_snapshots','professional_live_locations')
order by c.relname;

-- 6) STORAGE: buckets y policies reales
select
  'Q7_storage_buckets' as section,
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
order by id;

select
  'Q8_storage_policies' as section,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by policyname;

-- 7) LIVE LOCATION: columnas para validación de llegada
select
  'Q9_live_location_columns' as section,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'professional_live_locations'
order by ordinal_position;
