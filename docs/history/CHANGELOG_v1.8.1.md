# Changelog — FIXIS PRO v1.8.1

## Added
- Sincronización de presencia profesional con Supabase.
- Selector de radio de servicio: 5/8/15/25 km.
- Radar basado en `get_nearby_jobs()`.
- Distancia real en kilómetros en tarjetas de oportunidad.
- Captura GPS del lugar del servicio en flujo Cliente.

## Changed
- `accept_job()` deja de usarse desde Flutter.
- Aceptación de oportunidades mediante `accept_nearby_job()`.
- El dashboard deja de depender del stream directo de jobs pending.

## Security
- El backend vuelve a validar categoría, disponibilidad, ubicación y radio al aceptar.
- El cliente no controla `client_id`, status ni asignación.
