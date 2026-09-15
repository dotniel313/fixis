-- ============================================================
-- VALIDATE 026 — FIXIS PRO v1.9.3.0
-- ============================================================

-- 1. RPC
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'get_professional_payout_schedule';

-- Esperado: 1 fila, security_definer = true.


-- 2. Permisos
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND routine_name = 'get_professional_payout_schedule'
ORDER BY grantee;

-- Esperado:
-- authenticated EXECUTE
-- postgres EXECUTE
-- service_role EXECUTE
-- NO anon.


-- 3. Estado de liquidaciones recientes
SELECT
  id,
  professional_name,
  requested_amount,
  status,
  generated_by,
  scheduled_for,
  paid_at,
  payout_reference
FROM public.settlements
ORDER BY created_at DESC
LIMIT 20;

-- Un corte generado por Admin debe tener generated_by != null.
-- Una solicitud manual histórica normalmente tendrá generated_by = null.
