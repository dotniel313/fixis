-- ============================================================
-- TEST OPERATIVO v1.9.2.0
-- EJECUTAR DESDE LA APP/SESSION ADMIN PARA PROBAR LOS admin_*.
-- ============================================================

-- En SQL Editor auth.uid() normalmente no representa al admin de la app,
-- por lo que NO uses admin_create_weekly_settlements() desde SQL Editor
-- como prueba funcional de autenticación.
--
-- Desde Flutter/Admin la llamada será:
--
-- supabase.rpc(
--   'admin_create_weekly_settlements',
--   params: {
--     'p_cutoff_at': DateTime.now().toUtc().toIso8601String(),
--     'p_scheduled_for': 'YYYY-MM-DD'
--   },
-- );
--
-- Después comprobar:
SELECT
  s.id,
  s.professional_id,
  s.requested_amount,
  s.status,
  s.bank_name,
  s.bank_account_type,
  s.bank_account_number,
  s.scheduled_for,
  s.generated_by,
  COUNT(si.id) AS items,
  COALESCE(SUM(si.allocated_amount), 0) AS allocated
FROM public.settlements s
LEFT JOIN public.settlement_items si
  ON si.settlement_id = s.id
GROUP BY s.id
ORDER BY s.created_at DESC
LIMIT 20;
