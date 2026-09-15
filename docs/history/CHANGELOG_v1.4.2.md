# FIXIS PRO v1.4.2 — Duplicate Waiting Message Fix

## Cambios
- Se elimina el segundo bloque visual de `work_completed` en `JobDetailScreen`.
- Se conserva la tarjeta principal de estado con “Esperando confirmación del cliente”.
- No hay cambios de Supabase, RPC, ledger ni reglas financieras.
- No hay nuevas dependencias.

## Motivo
En v1.4.1 el estado `work_completed` se mostraba dos veces: una vez en `_buildStatusCard()` y nuevamente en `_buildWorkCompletedState()`.
