-- FIXIS: comprobaciones de solo lectura para el QA de cotizacion revisada.
-- Ejecutar en Supabase SQL Editor, primero bloque 1. Ejecutar bloque 2
-- solamente si las migraciones 028 y 031 estan realmente aplicadas.
-- Cero filas en cada consulta de anomalias = no se detecto esa anomalia;
-- no equivale a aprobar por si solo el recorrido funcional o la seguridad RLS.
-- No contiene INSERT, UPDATE, DELETE ni llamadas a RPC con efectos.

-- BLOQUE 1: instalacion real del backend. Cada indicador debe ser true.
SELECT
    to_regprocedure('public.submit_quote_revision(uuid,numeric,numeric,numeric,text,text)') IS NOT NULL
        AS revision_rpc,
    to_regprocedure('public.accept_quote_revision_customer(uuid)') IS NOT NULL
        AS accept_rpc,
    to_regprocedure('public.reject_quote_revision_customer(uuid)') IS NOT NULL
        AS reject_rpc,
    to_regprocedure('public.admin_get_payments_enriched(text[],integer)') IS NOT NULL
        AS admin_payments_rpc,
    EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'public.quotes'::regclass
          AND tgname = 'quote_revision_notification_trigger'
          AND NOT tgisinternal
          AND tgenabled <> 'D'
    ) AS revision_notification_trigger,
    EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public' AND tablename = 'jobs'
    ) AS jobs_realtime,
    EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public' AND tablename = 'notifications'
    ) AS notifications_realtime;

-- BLOQUE 2: ejecutar las SELECT siguientes tras confirmar bloque 1.
-- Cada una devuelve solamente casos que necesitan investigacion.

-- Revision pendiente y estado del trabajo deben coincidir.
SELECT id AS job_id, status, pending_quote_revision_id
FROM public.jobs
WHERE (status = 'quote_revision_pending')
      IS DISTINCT FROM (pending_quote_revision_id IS NOT NULL);

-- Cada trabajo con snapshot debe tener exactamente uno vigente, y ese
-- snapshot debe apuntar a la cotizacion aceptada por el trabajo.
SELECT j.id AS job_id, j.accepted_quote_id,
       count(s.id) AS snapshot_count,
       count(s.id) FILTER (WHERE s.is_current) AS current_count,
       max(s.quote_id::text) FILTER (WHERE s.is_current) AS current_quote_id
FROM public.jobs AS j
JOIN public.job_financial_snapshots AS s ON s.job_id = j.id
GROUP BY j.id, j.accepted_quote_id
HAVING count(s.id) FILTER (WHERE s.is_current) <> 1
    OR count(s.id) FILTER (WHERE s.is_current AND
       s.quote_id IS DISTINCT FROM j.accepted_quote_id) > 0;

-- Los pagos deben usar el snapshot del mismo trabajo y su importe bruto.
SELECT p.id AS payment_id, p.job_id, p.snapshot_id,
       s.job_id AS snapshot_job_id, p.service_amount, s.gross_amount
FROM public.payments AS p
JOIN public.job_financial_snapshots AS s ON s.id = p.snapshot_id
WHERE p.job_id IS DISTINCT FROM s.job_id
   OR p.service_amount IS DISTINCT FROM s.gross_amount;

-- Una comision contabilizada debe coincidir con el snapshot y no duplicarse
-- para el mismo trabajo y snapshot. No se exige que un trabajo sin pago
-- tenga comision: su ausencia aun puede ser normal.
SELECT le.job_id, le.snapshot_id,
       count(*) AS commission_entries,
       sum(le.amount) AS booked_amount,
       max(s.commission_amount) AS snapshot_commission
FROM public.financial_ledger_entries AS le
JOIN public.job_financial_snapshots AS s ON s.id = le.snapshot_id
WHERE le.entry_type = 'platform_commission'
  AND le.direction = 'credit' AND le.status <> 'reversed'
GROUP BY le.job_id, le.snapshot_id
HAVING count(*) <> 1
    OR sum(le.amount) IS DISTINCT FROM max(s.commission_amount)
    OR le.job_id IS DISTINCT FROM max(s.job_id::text)::uuid;

-- Revisiones aceptadas/rechazadas sin la notificacion persistente esperada.
SELECT q.job_id, q.id AS revision_id, q.status,
       q.professional_id
FROM public.quotes AS q
WHERE q.parent_quote_id IS NOT NULL
  AND q.status IN ('accepted', 'rejected')
  AND NOT EXISTS (
      SELECT 1 FROM public.notifications AS n
      WHERE n.job_id = q.job_id
        AND n.user_id = q.professional_id
        AND n.type = 'quote_revision_' || q.status
        AND n.idempotency_key = 'JOB:' || q.job_id::text ||
            ':QUOTE_REVISION:' || q.id::text || ':' || upper(q.status)
  );
