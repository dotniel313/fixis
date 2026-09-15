-- ============================================================
-- VALIDATE 024 — FIXIS PRO v1.9.2.3
-- ============================================================

-- 1. Función creada
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'admin_get_settlement_audit';

-- Esperado: 1 fila, security_definer = true.


-- 2. Permisos
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND routine_name = 'admin_get_settlement_audit'
ORDER BY grantee;

-- Esperado:
-- authenticated EXECUTE
-- postgres EXECUTE
-- service_role EXECUTE
-- NO anon


-- 3. Auditoría directa de la contabilidad (SQL Editor)
WITH item_totals AS (
  SELECT
    settlement_id,
    SUM(allocated_amount) AS allocated_amount
  FROM public.settlement_items
  GROUP BY settlement_id
),
debit_totals AS (
  SELECT
    settlement_id,
    COUNT(*) AS debit_count,
    SUM(amount) AS debit_amount
  FROM public.financial_ledger_entries
  WHERE entry_type = 'settlement_debit'
    AND direction = 'debit'
    AND settlement_id IS NOT NULL
  GROUP BY settlement_id
)
SELECT
  s.id,
  s.professional_name,
  s.requested_amount,
  s.status,
  s.payout_reference,
  COALESCE(it.allocated_amount, 0) AS allocated_amount,
  COALESCE(dt.debit_count, 0) AS debit_count,
  COALESCE(dt.debit_amount, 0) AS debit_amount,
  CASE
    WHEN s.status = 'paid'
      AND COALESCE(it.allocated_amount, 0) = s.requested_amount
      AND COALESCE(dt.debit_count, 0) = 1
      AND COALESCE(dt.debit_amount, 0) = s.requested_amount
      THEN 'OK'
    WHEN s.status = 'paid'
      THEN 'REVIEW'
    ELSE 'N/A'
  END AS paid_audit
FROM public.settlements s
LEFT JOIN item_totals it ON it.settlement_id = s.id
LEFT JOIN debit_totals dt ON dt.settlement_id = s.id
ORDER BY s.created_at DESC
LIMIT 30;
