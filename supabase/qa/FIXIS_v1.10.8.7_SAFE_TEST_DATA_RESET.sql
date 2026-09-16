-- FIXIS PRO v1.10.8.7
-- Limpieza segura de datos transaccionales de prueba
-- Fecha: 2026-09-16
--
-- IMPORTANTE
-- 1. Este script espera exactamente el estado auditado:
--      jobs = 12, payments = 6, platform_commissions = 9, settlements = 5.
-- 2. Conserva auth.users, profiles, categorias, commission_rules,
--    financial_accounts, funciones, RLS y estructura.
-- 3. La primera transaccion crea un respaldo persistente.
-- 4. La segunda transaccion termina en ROLLBACK por defecto.
-- 5. Para aplicar la limpieza, cambie SOLO el ROLLBACK final por COMMIT
--    despues de revisar que el ensayo termina sin errores.

-- ============================================================================
-- FASE A. RESPALDO PERSISTENTE E INMUTABLE DEL ESTADO PREVIO
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS fixis_backup_reset_20260916;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.jobs
AS TABLE public.jobs;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.quotes
AS TABLE public.quotes;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.job_financial_snapshots
AS TABLE public.job_financial_snapshots;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.financial_ledger_entries
AS TABLE public.financial_ledger_entries;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.payments
AS TABLE public.payments;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.payment_allocations
AS TABLE public.payment_allocations;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.payment_evidence
AS TABLE public.payment_evidence;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.payment_reconciliation
AS TABLE public.payment_reconciliation;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.settlements
AS TABLE public.settlements;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.settlement_items
AS TABLE public.settlement_items;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.job_attachments
AS TABLE public.job_attachments;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.professional_live_locations
AS TABLE public.professional_live_locations;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.notifications
AS TABLE public.notifications;

-- Snapshot materializado de las entradas de comision del ledger.
CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.platform_commissions
AS
SELECT *
FROM public.financial_ledger_entries
WHERE entry_type = 'platform_commission';

-- Solo se respaldan las metricas de los profesionales afectados.
CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.profile_job_stats
AS
SELECT DISTINCT
    p.id,
    p.total_jobs
FROM public.profiles p
JOIN public.job_financial_snapshots fs
  ON fs.professional_id = p.id;

CREATE TABLE IF NOT EXISTS fixis_backup_reset_20260916.expert_gamification
AS
SELECT eg.*
FROM public.expert_gamification eg
WHERE eg.pro_id IN (
    SELECT DISTINCT fs.professional_id
    FROM public.job_financial_snapshots fs
);

COMMIT;

-- Verificacion del respaldo. Cada tabla debe existir antes de continuar.
SELECT
    to_regclass('fixis_backup_reset_20260916.jobs') AS backup_jobs,
    to_regclass('fixis_backup_reset_20260916.payments') AS backup_payments,
    to_regclass('fixis_backup_reset_20260916.financial_ledger_entries') AS backup_ledger,
    to_regclass('fixis_backup_reset_20260916.settlements') AS backup_settlements;

-- ============================================================================
-- FASE B. ENSAYO DE LIMPIEZA TRANSACCIONAL
-- ============================================================================

BEGIN;

-- Evita que entren nuevos trabajos mientras se ejecuta el ensayo.
LOCK TABLE public.jobs IN SHARE ROW EXCLUSIVE MODE;

-- El conjunto objetivo proviene del respaldo persistente. Esto evita depender
-- de tablas TEMP, que algunos editores SQL pueden perder entre sentencias.

-- Barrera de seguridad: aborta si la base ya no coincide con la auditoria.
DO $safety$
DECLARE
    v_jobs bigint;
    v_payments bigint;
    v_commissions bigint;
    v_settlements bigint;
BEGIN
    SELECT count(*) INTO v_jobs FROM public.jobs;
    SELECT count(*) INTO v_payments FROM public.payments;
    SELECT count(*)
    INTO v_commissions
    FROM public.financial_ledger_entries
    WHERE entry_type = 'platform_commission';
    SELECT count(*) INTO v_settlements FROM public.settlements;

    IF v_jobs <> 12
       OR v_payments <> 6
       OR v_commissions <> 9
       OR v_settlements <> 5 THEN
        RAISE EXCEPTION
            'Limpieza cancelada. Estado esperado jobs=12, payments=6, commissions=9, settlements=5; estado real jobs=%, payments=%, commissions=%, settlements=%',
            v_jobs, v_payments, v_commissions, v_settlements;
    END IF;

    IF EXISTS (
        SELECT id FROM public.jobs
        EXCEPT
        SELECT id FROM fixis_backup_reset_20260916.jobs
    ) OR EXISTS (
        SELECT id FROM fixis_backup_reset_20260916.jobs
        EXCEPT
        SELECT id FROM public.jobs
    ) THEN
        RAISE EXCEPTION
            'Limpieza cancelada. Los IDs actuales de jobs no coinciden con el respaldo persistente.';
    END IF;
END
$safety$;

-- Rompe referencias circulares/logicas antes de eliminar cotizaciones.
UPDATE public.jobs
SET
    accepted_quote_id = NULL,
    pending_quote_revision_id = NULL
WHERE id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

UPDATE public.quotes
SET parent_quote_id = NULL
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

-- Notificaciones generadas por trabajos o liquidaciones de prueba.
DELETE FROM public.notifications
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs)
   OR settlement_id IN (SELECT id FROM public.settlements);

-- Hijos directos de pagos.
DELETE FROM public.payment_allocations
WHERE payment_id IN (SELECT id FROM public.payments)
   OR job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

DELETE FROM public.payment_evidence
WHERE payment_id IN (SELECT id FROM public.payments);

DELETE FROM public.payment_reconciliation
WHERE payment_id IN (SELECT id FROM public.payments);

-- Los items deben salir antes del ledger y de settlements por sus FK RESTRICT.
DELETE FROM public.settlement_items;

-- Fuente contable transaccional. Las cuentas financieras se conservan.
DELETE FROM public.financial_ledger_entries;

-- Pagos y liquidaciones de prueba.
DELETE FROM public.payments;
DELETE FROM public.settlements;

-- Snapshots antes de quotes por job_financial_snapshot_quote_fk RESTRICT.
DELETE FROM public.job_financial_snapshots
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

DELETE FROM public.quotes
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

-- Estas dos tablas tienen CASCADE, pero el borrado explicito facilita auditoria.
DELETE FROM public.job_attachments
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

DELETE FROM public.professional_live_locations
WHERE job_id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

-- Tabla principal al final.
DELETE FROM public.jobs
WHERE id IN (SELECT id FROM fixis_backup_reset_20260916.jobs);

-- Recompone estadisticas derivadas que no tienen FK hacia jobs.
UPDATE public.profiles
SET total_jobs = 0
WHERE id IN (
    SELECT DISTINCT professional_id
    FROM fixis_backup_reset_20260916.job_financial_snapshots
    WHERE professional_id IS NOT NULL
);

UPDATE public.expert_gamification
SET
    current_rank = 'Inicial',
    completed_jobs_count = 0,
    target_jobs_count = 5,
    badges = '[]'::jsonb,
    updated_at = now()
WHERE pro_id IN (
    SELECT DISTINCT professional_id
    FROM fixis_backup_reset_20260916.job_financial_snapshots
    WHERE professional_id IS NOT NULL
);

-- Validacion obligatoria dentro de la misma transaccion.
DO $validation$
DECLARE
    v_jobs bigint;
    v_quotes bigint;
    v_snapshots bigint;
    v_ledger bigint;
    v_payments bigint;
    v_commissions bigint;
    v_settlements bigint;
    v_settlement_items bigint;
BEGIN
    SELECT count(*) INTO v_jobs FROM public.jobs;
    SELECT count(*) INTO v_quotes FROM public.quotes;
    SELECT count(*) INTO v_snapshots FROM public.job_financial_snapshots;
    SELECT count(*) INTO v_ledger FROM public.financial_ledger_entries;
    SELECT count(*) INTO v_payments FROM public.payments;
    SELECT count(*)
    INTO v_commissions
    FROM public.financial_ledger_entries
    WHERE entry_type = 'platform_commission';
    SELECT count(*) INTO v_settlements FROM public.settlements;
    SELECT count(*) INTO v_settlement_items FROM public.settlement_items;

    IF v_jobs <> 0
       OR v_quotes <> 0
       OR v_snapshots <> 0
       OR v_ledger <> 0
       OR v_payments <> 0
       OR v_commissions <> 0
       OR v_settlements <> 0
       OR v_settlement_items <> 0 THEN
        RAISE EXCEPTION
            'Validacion fallida: jobs=%, quotes=%, snapshots=%, ledger=%, payments=%, commissions=%, settlements=%, settlement_items=%',
            v_jobs, v_quotes, v_snapshots, v_ledger,
            v_payments, v_commissions, v_settlements, v_settlement_items;
    END IF;
END
$validation$;

-- Resultado del ensayo: debe mostrar ceros.
SELECT
    (SELECT count(*) FROM public.jobs) AS jobs,
    (SELECT count(*) FROM public.quotes) AS quotes,
    (SELECT count(*) FROM public.job_financial_snapshots) AS snapshots,
    (SELECT count(*) FROM public.financial_ledger_entries) AS ledger_entries,
    (SELECT count(*) FROM public.payments) AS payments,
    (
        SELECT count(*)
        FROM public.financial_ledger_entries
        WHERE entry_type = 'platform_commission'
    ) AS platform_commissions,
    (SELECT count(*) FROM public.settlements) AS settlements,
    (SELECT count(*) FROM public.settlement_items) AS settlement_items;

-- MODO SEGURO: la primera ejecucion NO borra los datos.
ROLLBACK;

-- Para la ejecucion definitiva, cambie unicamente la linea anterior por:
-- COMMIT;
