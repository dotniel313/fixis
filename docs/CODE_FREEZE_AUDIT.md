# FIXIS PRO — Code Freeze Audit

Fecha de auditoría: 2026-09-10
Base revisada: ZIP entregado por el usuario (`Archivo(1).zip`), correspondiente al estado local posterior a v1.8.5.1.

## Resumen ejecutivo

El núcleo transaccional de FIXIS está en buen estado conceptual y funcional: roles, cotizaciones, snapshots, ledger, wallet, retiros, cliente real, matching PostGIS y tracking live están bien encaminados. Sin embargo, el repositorio local y la base desplegada se han separado. El riesgo principal actual no es funcional sino de reproducibilidad, deuda técnica y mantenimiento.

### Semáforo
- Verde: flujo Cliente→FIXI, cotizaciones, comisión/snapshot, ledger, wallet, RLS, matching geo.
- Amarillo: FIXIS Live foreground, perfiles, navegación, documentación/versionado.
- Rojo: migraciones incompletas en repo, ausencia de pubspec/analysis_options en el paquete auditado, tests automatizados inexistentes, notificaciones demo, Drift desactualizado.

## Hallazgos críticos

### AUD-001 — Historial de migraciones incompleto [CRÍTICO]
En `supabase/migrations/` solo están: 003, 006, 008, 011, 013 y 015.
Faltan migraciones que sí forman parte de la base desplegada, entre otras: 001/002/004/005/007/009/010/012/014/016.
Impacto: el repositorio no puede reconstruir Supabase desde cero ni reproducir staging/CI.
Acción: recuperar/exportar las migraciones faltantes y crear una línea base reproducible antes de nuevas features.

### AUD-002 — Paquete sin pubspec.yaml ni analysis_options.yaml [ALTO]
No se incluyeron `pubspec.yaml` ni `analysis_options.yaml` en el ZIP auditado.
Impacto: no se puede validar dependencias (`flutter_map`, `latlong2`, Drift, Supabase, Riverpod) ni ejecutar un `flutter analyze` reproducible sobre este snapshot.
Acción: incorporar ambos archivos en la próxima línea base.

### AUD-003 — Cero tests automatizados [CRÍTICO]
No hay archivos `*_test.dart` ni suite visible en el paquete.
Impacto: cada parche puede romper silenciosamente el ciclo de negocio.
Prioridad de tests: create_job → matching → accept → quote → customer accept → route → arrived → start → finish → customer approve → ledger → wallet → settlement.

## Deuda funcional / UI

### UI-002 — Notificaciones hardcodeadas [ALTO]
`notifications_screen.dart` contiene eventos ficticios: transferencia de $142.50, servicio completado y rango Platino.
Acción: ocultar esta pantalla temporalmente o sustituir por estado vacío hasta implementar notificaciones reales.

### GAM-002 — Fallback visual legacy [MEDIO]
`gamification_screen.dart` usa fallback `Platino` y `target=50`.
Acción: `Inicial` y target real del backend; idealmente modelos tipados.

### LEG-004 — JobSuccessScreen obsoleta [MEDIO]
La pantalla aún dice “Liquidación pendiente de Financial Core”, aunque Financial Core ya existe.
Acción: eliminarla del flujo y después retirar el archivo si no hay referencias.

### LEG-005 — Estado `completed` legacy visible [BAJO/MEDIO]
La UI sigue contemplando `completed` por compatibilidad histórica.
Acción: mantener solo como lectura histórica; no permitir nuevas transiciones hacia ese estado.

## Arquitectura

### ARC-004 — Supabase dentro de pantallas [MEDIO]
`profile_screen.dart`, `wallet_screen.dart` y `gamification_screen.dart` acceden directamente a Supabase.
Acción: mover todo acceso a repositories/services/providers.

### ARC-005 — 89 usos de Map<String,dynamic> [MEDIO]
Jobs, quotes, wallet, profile y customer usan mapas crudos.
Acción: introducir modelos tipados gradualmente (Job, Quote, FinancialSnapshot, WalletSummary, Settlement, LiveLocation).

### ARC-006 — Navegación dispersa [MEDIO]
Se detectan 13 usos de `MaterialPageRoute`.
Acción: consolidar navegación por rol y deep links en router central cuando se estabilice la base.

### OFF-001 — Drift desactualizado [ALTO]
La tabla local solo conoce `pending/in_progress/completed`, no la state machine actual.
Acción: no declarar offline-first todavía; rediseñar almacenamiento/cola después del code freeze.

### LIVE-001 — Tracking solo foreground [CONOCIDO]
FIXIS Live publica ubicación mientras permanece abierta la pantalla del trabajo.
Acción: mantener como limitación explícita; background tracking será una fase separada por permisos iOS/Android.

## Documentación y versiones

### DOC-001 — Documentación fragmentada [MEDIO]
Hay múltiples changelogs/checklists versionados pero no un changelog maestro ni una bitácora única.
Acción: crear `docs/CHANGELOG.md`, `docs/ERROR_LOG.md`, `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md` y `docs/RELEASE_CHECKLIST.md`.

### DOC-002 — Huecos de versión [MEDIO]
No hay documentación consistente para todas las migraciones/features intermedias (por ejemplo v1.7.x y algunas subversiones backend).
Acción: reconstruir historial desde Supabase real y nuestra bitácora.

## Métricas rápidas del snapshot
- 24 archivos Dart.
- 89 referencias a `Map<String,dynamic>`.
- 13 usos de `MaterialPageRoute`.
- 6 archivos acceden directa o indirectamente a `Supabase.instance.client`.
- 0 tests automatizados detectados.
- 6 migraciones SQL presentes localmente.

## Recomendación de freeze

Crear `v1.8.5.2 — Stabilization & Consolidation` sin nuevas features.

Orden:
1. Reconciliar migraciones locales vs Supabase desplegado.
2. Recuperar `pubspec.yaml` y `analysis_options.yaml` en la línea base.
3. Desactivar/eliminar UI demo visible.
4. Corregir gamificación legacy y JobSuccess.
5. Crear bitácora/changelog maestros.
6. Agregar tests de dominio/RPC y smoke tests Flutter.
7. Ejecutar `flutter analyze` y pruebas end-to-end.
8. Etiquetar baseline estable.
9. Recién después retomar mapa/ETA/perfiles premium.

## Criterio de salida de v1.8.5.2
- `flutter analyze`: 0 errores, 0 warnings.
- Todas las migraciones necesarias presentes y ordenadas.
- Base reproducible desde cero en proyecto de prueba.
- Ninguna pantalla muestra valores financieros o gamificación ficticios.
- Flujo end-to-end crítico probado.
- Ledger y settlement reconciliados.
- README/CHANGELOG/ERROR_LOG únicos y actualizados.
