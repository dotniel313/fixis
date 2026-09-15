-- ============================================================
-- VALIDATE 023 — FIXIS PRO v1.9.2.2
-- ============================================================

-- 1. Columna
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'settlements'
  AND column_name = 'professional_name';

-- Esperado: 1 fila / text.


-- 2. Backfill
SELECT
  id,
  professional_id,
  professional_name,
  requested_amount,
  status,
  scheduled_for
FROM public.settlements
ORDER BY created_at DESC
LIMIT 20;

-- Esperado:
-- professional_name ya no debe estar NULL/vacío para los registros
-- asociados a un profile existente.


-- 3. Trigger
SELECT
  trigger_name,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'settlements'
  AND trigger_name = 'trg_settlement_professional_name';

-- Esperado: INSERT + UPDATE, BEFORE.
