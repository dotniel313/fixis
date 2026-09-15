# FIXIS — Master Status

Última actualización: 2026-09-15

## Versiones

- Baseline estable Git: `v1.10.8.5`
- Rama estable: `main`
- Rama de integración: `develop`
- Desarrollo actual: `v1.10.8.6-dev`
- Rama actual de feature: `feature/v1.10.8.6-revised-quote`

## Estado general

### Flutter
- Android: QA físico en curso
- iOS: QA físico en curso
- Web: no es objetivo principal del release móvil actual

### Backend
- Supabase activo
- RLS habilitado en entidades críticas
- Escrituras financieras críticas mediante RPC
- Reconciliación migraciones/backend pendiente de cierre documental

## Release actual

### v1.10.8.5
Estado: baseline Git

Incluye:
- Admin Human Readable
- mejoras QA anteriores
- estabilidad iOS
- SafeArea Android
- mejoras de fotografías
- Job Intake
- Arrival Guard

Nota:
La validación física/backend completa de v1.10.8.5 debe mantenerse documentada en QA.

## Desarrollo v1.10.8.6

Objetivo:
Cotización revisada por cambio de alcance antes de iniciar el trabajo.

Flujo:

initial quote accepted
→ route
→ arrived
→ scope changed
→ revised quote
→ customer accept/reject
→ arrived
→ in_progress

Reglas principales:

- revisión únicamente en estado `arrived`
- motivo obligatorio
- cotización original inmutable
- cliente compara original vs revisión
- rechazo conserva economía original
- aceptación genera nueva economía vigente
- un solo snapshot financiero current por job
- mientras existe revisión pendiente no puede iniciar el trabajo
- no modificar ledger ya contabilizado
- comisión conserva regla congelada correspondiente

## Prioridades inmediatas

1. Consolidar baseline GitHub
2. Configurar documentación maestra
3. Configurar CI
4. Implementar v1.10.8.6
5. Ejecutar QA
6. PR hacia develop
7. Release posterior a PASS

## Principio financiero

Flutter no determina dinero autoritativo.

Fuente de verdad:

quote
→ financial snapshot
→ payment
→ ledger
→ settlement

Los cambios monetarios críticos deben ejecutarse mediante backend/RPC.

## Regla de release

Una versión solo se cierra cuando:

DEV
→ QA
→ physical test
→ PASS
→ release
