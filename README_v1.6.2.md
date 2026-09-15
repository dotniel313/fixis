# FIXIS PRO v1.6.2 — Flutter Analyze Cleanup

Patch sobre v1.6.1 Customer Foundation.

Cambios:
- Corrige `const_with_non_const` en `customer_job_detail_screen.dart`.
- Marca `Scaffold` de carga como const en `auth_gate_screen.dart`.
- Reemplaza `withOpacity` por `withValues(alpha: ...)` en gamificación.
- Marca `AlwaysStoppedAnimation` como const.
- Elimina import no usado en notificaciones.
- Elimina `_buildWorkCompletedState()` no referenciado.

No contiene cambios de base de datos ni nuevas migraciones.
