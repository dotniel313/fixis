# FIXIS PRO v1.8.5.2 — Stabilization Baseline

## Propósito
Esta versión congela nuevas funcionalidades para reconciliar código, documentación y backend antes de continuar con mapa/rutas/ETA.

## Estado funcional conservado
- Roles customer/professional y control de acceso.
- Creación segura de jobs.
- Matching geográfico PostGIS.
- Cotizaciones y autorización de cliente.
- Snapshot financiero y comisión sobre mano de obra.
- Flujo route/en_route/arrived/in_progress/work_completed/customer_approved.
- Ledger financiero, wallet y settlements.
- FIXIS Live foreground + Realtime.
- Mapa cliente/FIXIS Pulse permanece en código, pendiente de validación funcional final.

## Correcciones de estabilización
- Se eliminaron notificaciones ficticias.
- Gamificación ya no inventa Platino, insignias ni calificaciones.
- JobSuccess ya no dice que Financial Core está pendiente.
- Navegación externa ya no usa coordenadas fallback de Ecuador.
- Documentación histórica movida a `docs/history/`.
- Se añadió `supabase/reconciliation/001_extract_live_backend.sql`.

## Bloqueadores de baseline reproducible
1. El ZIP recibido no contiene `pubspec.yaml`.
2. El ZIP recibido no contiene `analysis_options.yaml`.
3. El historial local de migraciones es incompleto respecto al backend desplegado.
4. No existen tests automatizados en el snapshot recibido.

## Regla de release
v1.8.5.2 no se considera baseline cerrada hasta:
- recuperar `pubspec.yaml` + `analysis_options.yaml`;
- ejecutar el script de reconciliación y reconstruir las migraciones faltantes desde definiciones reales;
- `flutter analyze` sin errores;
- prueba manual end-to-end del flujo crítico.
