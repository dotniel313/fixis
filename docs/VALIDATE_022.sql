-- ============================================================
-- VALIDATE 022 — FIXIS PRO v1.9.2.0
-- ============================================================

-- 1) Columnas nuevas
SELECT
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'settlements'
  AND column_name IN (
    'scheduled_for',
    'generated_by',
    'processed_by',
    'paid_by',
    'rejected_by',
    'payout_reference',
    'payment_notes'
  )
ORDER BY column_name;

-- Esperado: 7 filas.


-- 2) Wrappers admin y trusted generator
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_weekly_settlements_trusted',
    'admin_create_weekly_settlements',
    'admin_mark_settlement_processing',
    'admin_mark_settlement_paid',
    'admin_reject_settlement'
  )
ORDER BY p.proname;

-- Esperado: 5 filas, security_definer = true.


-- 3) Privilegios
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND routine_name IN (
    'create_weekly_settlements_trusted',
    'admin_create_weekly_settlements',
    'admin_mark_settlement_processing',
    'admin_mark_settlement_paid',
    'admin_reject_settlement'
  )
ORDER BY routine_name, grantee;

-- Clave:
-- authenticated NO debe ejecutar create_weekly_settlements_trusted.
-- authenticated SÍ debe ejecutar los cuatro admin_*.


-- 4) Policies admin
SELECT
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname IN (
    'settlements_select_admin',
    'settlement_items_select_admin'
  )
ORDER BY tablename;

-- Esperado: 2 filas SELECT.


-- 5) Estado actual de liquidaciones
SELECT
  id,
  professional_id,
  requested_amount,
  status,
  scheduled_for,
  payout_reference,
  created_at
FROM public.settlements
ORDER BY created_at DESC
LIMIT 20;
