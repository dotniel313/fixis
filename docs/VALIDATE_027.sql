-- ============================================================
-- VALIDATE 027 — FIXIS PRO v1.9.3.1
-- ============================================================

-- 1) Tabla y RLS
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'notifications';

-- Esperado: notifications | true


-- 2) Policies
SELECT
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'notifications'
ORDER BY policyname;

-- Esperado:
-- notifications_select_own | SELECT
-- notifications_update_own | UPDATE


-- 3) Trigger
SELECT
  tgname,
  tgenabled
FROM pg_trigger
WHERE tgrelid = 'public.settlements'::regclass
  AND NOT tgisinternal
  AND tgname = 'settlement_notification_trigger';

-- Esperado: 1 fila, O


-- 4) Realtime publication
SELECT
  pubname,
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename = 'notifications';

-- Esperado: 1 fila.


-- 5) Notificaciones reales existentes/backfill
SELECT
  id,
  user_id,
  type,
  title,
  body,
  settlement_id,
  read_at,
  created_at
FROM public.notifications
ORDER BY created_at DESC
LIMIT 20;

-- Para el caso ya probado de US$255 pagado debe aparecer
-- settlement_paid con referencia de pago.


-- 6) No duplicados lógicos
SELECT
  idempotency_key,
  COUNT(*) AS rows
FROM public.notifications
GROUP BY idempotency_key
HAVING COUNT(*) > 1;

-- Esperado: 0 filas.
