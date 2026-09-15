# FIXIS PRO v1.8.5.2 — Stabilization & Consolidation Plan

## Regla de esta versión
No incorporar nuevas funciones de producto.

## Fase A — Reproducibilidad
- Recuperar todas las migraciones SQL ejecutadas.
- Ordenarlas y verificar dependencias.
- Incorporar pubspec.yaml y analysis_options.yaml.
- Eliminar `__MACOSX` y residuos de empaquetado.

## Fase B — Limpieza funcional
- Sustituir Notifications demo por empty state o backend real.
- Cambiar fallback Gamification de Platino/50 a Initial/configurado.
- Retirar JobSuccessScreen del flujo.
- Confirmar que ningún RPC legacy (`complete_job_v1`, `accept_job`) sea invocado por Flutter.

## Fase C — Arquitectura mínima
- Crear modelos tipados: Job, Quote, FinancialSnapshot, WalletSummary, Settlement, LiveLocation.
- Mover Wallet/Profile/Gamification data access a repositories.
- Crear catálogo único de estados de Job en Dart.

## Fase D — QA
- Unit tests de normalización/cálculos/presentación de estados.
- Integration tests de repositories/RPC con proyecto de test.
- Smoke test manual end-to-end en dos usuarios.
- Prueba de idempotencia ledger/settlement.
- Prueba de RLS negativa (usuario A no lee job/live de B).

## Fase E — Documentación
- README.md actual.
- docs/CHANGELOG.md maestro.
- docs/ERROR_LOG.md maestro.
- docs/STATE_MACHINE.md.
- docs/ARCHITECTURE.md.
- docs/RELEASE_CHECKLIST.md.

## Definition of Done
- Flutter analyze limpio.
- Migraciones completas y reproducibles.
- Cero datos demo visibles.
- Tests críticos verdes.
- Flujo marketplace + financiero intacto.
- Baseline etiquetada como v1.8.5.2.
