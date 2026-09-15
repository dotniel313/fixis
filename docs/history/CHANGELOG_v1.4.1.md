# FIXIS PRO v1.4.1 — Finish Job State Patch

## Cambios
- `JobsRepository.completeJob()` fue reemplazado por `finishJob()` usando RPC `public.finish_job()`.
- El cierre técnico ahora transiciona `in_progress -> work_completed`.
- Después de subir evidencia, la app ya no abre la pantalla legacy de trabajo completado.
- Se muestra `Esperando confirmación del cliente` hasta la aprobación trusted.
- `work_completed` y `customer_approved` permanecen visibles en Mis servicios activos.
- Se agregó presentación de estado `customer_approved` con el snapshot financiero.

## Bug corregido
- `DB/APP-001`: Flutter seguía usando `complete_job_v1`, incompatible con la state machine v1.4.0.
