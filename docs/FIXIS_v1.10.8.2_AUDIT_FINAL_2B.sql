-- FIXIS PRO v1.10.8.2 — LIVE BACKEND AUDIT / FASE 2B
-- SOLO LECTURA. Dos salidas pendientes antes de la migración final.

-- A) Columnas reales del snapshot financiero
select
  'A_snapshot_columns' as section,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'job_financial_snapshots'
order by ordinal_position;

-- B) Buckets reales de Storage
select
  'B_storage_buckets' as section,
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
order by id;
