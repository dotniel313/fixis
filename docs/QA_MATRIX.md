# FIXIS — QA Matrix

Ultima actualizacion: 2026-09-17

## Estados

- PASS
- FAIL
- PENDING
- BLOCKED

## Release actual

| Area | Estado | Evidencia |
|---|---|---|
| Flutter Analyze | PASS | GitHub Actions en HEAD 341f786f |
| Flutter Test | BLOCKED | No existen tests automatizados suficientes |
| Android Build | PENDING | Requiere validacion del release actual |
| Android Physical QA | PENDING | Requiere dispositivo |
| iOS Build | PASS | Compilacion e instalacion mediante flutter run en iPhone 15 |
| iOS Install/Launch Smoke | PASS | Runner inicio correctamente; pausa observada correspondia a breakpoint local de Xcode |
| iOS Physical QA | PENDING | Falta ejecutar el flujo funcional end-to-end |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline | PASS | jobs, quotes, snapshots, ledger, payments, commissions, settlements y settlement_items = 0 |
| Revised Quote Flow | PENDING | E2E llego hasta aceptacion de revision; continuar tras hotfix |
| Quote Revision Realtime | PENDING | Migracion 031 y suscripcion Flutter preparadas; falta aplicar y validar |
| Revision Notification FIXI | PENDING | Evento persistente e in-app preparado; falta QA fisico |
| Finance Regression | PENDING | quote -> snapshot -> payment -> ledger -> settlement |
| Security Regression | PENDING | Validar RLS y RPC despues del E2E |

## Criterios v1.10.8.6

- Preserva cotizacion original
- Revision solo en arrived
- Motivo obligatorio
- Cliente visualiza comparacion
- Rechazo conserva snapshot anterior
- Aceptacion crea snapshot vigente
- Solo un snapshot current
- Revision pendiente bloquea start_job
- Payment usa snapshot vigente
- Ledger usa snapshot vigente
- No duplica earning
- No duplica commission

## Regla de cierre

La version no puede pasar a release mientras Revised Quote Flow,
Finance Regression, Security Regression y QA fisico permanezcan en PENDING
o BLOCKED.
