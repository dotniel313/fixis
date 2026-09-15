# FIXIS PRO v1.4.1

Parche de alineación Flutter con la state machine financiera v1.4.0.

## Orden de instalación
1. Respaldar `lib` actual.
2. Reemplazar `lib` con la de este paquete.
3. Ejecutar `flutter clean`, `flutter pub get`, `flutter analyze`.
4. Probar cierre de trabajo desde un job `in_progress`.
5. Confirmar en Supabase que el estado queda `work_completed`.
6. Solo después probar `approve_completed_job_trusted()`.

No requiere una nueva migración antes de la prueba porque `finish_job()` fue creada en Migration 009.
