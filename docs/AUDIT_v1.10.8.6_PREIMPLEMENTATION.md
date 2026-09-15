# FIXIS — v1.10.8.6 Pre-Implementation Audit

Fecha: 2026-09-15

## Feature

Revised Quote / Change of Scope

## Estado

PRE-IMPLEMENTATION AUDIT COMPLETE

## Hallazgo principal

El frontend Flutter contiene implementación parcial/anticipada del flujo
Revised Quote, pero las migraciones Supabase versionadas no contienen el
modelo ni los RPC necesarios para reproducir ese flujo.

## Flutter existente

Confirmado:

- submitQuoteRevision()
- cancelQuoteRevision()
- acceptQuoteRevision()
- rejectQuoteRevision()
- RevisionQuoteScreen
- quote_revision_pending
- pending_quote_revision_id
- UI cliente para aceptar/rechazar revisión

## Backend versionado

No encontrados:

- revision_number
- parent_quote_id
- revision_reason
- pending_quote_revision_id
- is_current
- superseded_at
- superseded_by_snapshot_id
- quote_revision_pending
- superseded

RPC no encontrados:

- submit_quote_revision
- accept_quote_revision_customer
- reject_quote_revision_customer
- cancel_quote_revision

## Constraint incompatible

Modelo histórico quotes:

UNIQUE(job_id, professional_id)

Este constraint impide múltiples versiones de cotización para el mismo
trabajo y profesional.

Debe evolucionar hacia:

UNIQUE(job_id, professional_id, revision_number)

## Modelo financiero requerido

Un job puede tener múltiples snapshots históricos pero máximo un snapshot
vigente.

Requerido:

- is_current
- superseded_at
- superseded_by_snapshot_id

Debe existir una restricción única parcial para garantizar máximo un
snapshot current por job.

## Regla de revisión

La revisión solo puede iniciarse cuando:

job.status = arrived

y antes de:

job.status = in_progress

Mientras existe una revisión pendiente:

start_job() debe estar bloqueado.

## Decisión cliente

Reject:

- revised quote -> rejected
- original quote remains accepted
- original snapshot remains current
- job -> arrived

Accept:

- original quote -> superseded
- original snapshot -> not current
- revised quote -> accepted
- new snapshot -> current
- accepted_quote_id -> revised quote
- pending_quote_revision_id -> null
- job -> arrived

## Comisión

La revisión debe preservar la regla de comisión congelada asociada al
snapshot financiero original.

No debe seleccionar una nueva regla global de comisión solamente porque
haya cambiado después de la aceptación original.

## Payments / Ledger

prepare_job_payment debe usar el snapshot correspondiente a:

- job_id
- accepted_quote_id
- is_current = true

La aprobación financiera posterior debe mantener esa misma relación.

No deben existir duplicados de:

- professional_earning
- platform_commission

## Migration audit

Se detectaron dos archivos con secuencia 018:

- 018_job_intake_arrival_guard_v1_10_8_2.sql
- 018_payments_foundation_v1_9_0.sql

ID:

AUD-MIG-001

Severidad:

HIGH

No renombrar migraciones históricas sin reconciliar primero contra la
tabla de migraciones del backend desplegado.

## Nueva migración propuesta

028_revised_quote_flow_v1_10_8_6.sql

## Estado QA inicial

Flutter implementation: PARTIAL / PRESENT
Git SQL implementation: FAIL
Versioned quotes: FAIL
Versioned snapshots: FAIL
Payment compatibility: PENDING
Ledger compatibility: PENDING
Live backend reconciliation: REQUIRED BEFORE APPLY
