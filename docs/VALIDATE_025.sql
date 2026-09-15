-- ============================================================
-- VALIDATE 025 — FIXIS PRO v1.9.2.4
-- ============================================================

-- 1) RPCs
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'admin_get_platform_revenue_summary',
    'admin_get_platform_commission_entries'
  )
ORDER BY p.proname;

-- Esperado: 2 filas / security_definer = true.


-- 2) Privilegios
SELECT
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND routine_name IN (
    'admin_get_platform_revenue_summary',
    'admin_get_platform_commission_entries'
  )
ORDER BY routine_name, grantee;

-- Esperado:
-- authenticated, postgres, service_role
-- NO anon.


-- 3) Cuenta FIXIS
SELECT
  id,
  account_code,
  account_type,
  currency,
  active
FROM public.financial_accounts
WHERE account_code = 'FIXIS_REVENUE_USD';

-- Esperado:
-- account_type = platform_revenue
-- currency = USD
-- active = true


-- 4) Auditoría directa de comisiones
SELECT
  le.id AS ledger_entry_id,
  le.job_id,
  j.title,
  fs.gross_amount,
  fs.labor_amount,
  fs.materials_amount,
  fs.commission_rate_percent,
  fs.commission_amount AS snapshot_commission,
  le.amount AS ledger_commission,
  fs.professional_amount,
  CASE
    WHEN le.amount = fs.commission_amount
      THEN 'OK'
    ELSE 'REVIEW'
  END AS audit
FROM public.financial_ledger_entries le
JOIN public.financial_accounts fa
  ON fa.id = le.account_id
JOIN public.job_financial_snapshots fs
  ON fs.id = le.snapshot_id
JOIN public.jobs j
  ON j.id = le.job_id
WHERE fa.account_code = 'FIXIS_REVENUE_USD'
  AND le.entry_type = 'platform_commission'
  AND le.direction = 'credit'
  AND le.status <> 'reversed'
ORDER BY le.created_at DESC
LIMIT 50;


-- 5) Saldo actual de cuenta FIXIS
SELECT
  fa.account_code,
  COALESCE(
    SUM(
      CASE
        WHEN le.direction = 'credit' THEN le.amount
        ELSE -le.amount
      END
    ),
    0
  ) AS ledger_balance
FROM public.financial_accounts fa
LEFT JOIN public.financial_ledger_entries le
  ON le.account_id = fa.id
 AND le.status <> 'reversed'
WHERE fa.account_code = 'FIXIS_REVENUE_USD'
GROUP BY fa.account_code;
