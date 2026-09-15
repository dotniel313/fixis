# FIXIS PRO v1.3.0 — Approved Quote + Start Job

## Cambios
- El detalle del servicio refresca job, cotización y snapshot financiero desde Supabase.
- Estado `authorized` muestra monto total, comisión FIXIS y monto del profesional.
- Se agrega `start_job()` seguro vía RPC.
- El FIXI no puede iniciar sin cotización aceptada y snapshot financiero.
- `QuoteSummaryScreen` distingue `draft`, `submitted` y `accepted`.
- No se generan movimientos de wallet ni liquidaciones en esta versión.

## Seguridad
- Flutter continúa sin `UPDATE` directo sobre `jobs`.
- La transición `authorized -> in_progress` ocurre únicamente mediante `public.start_job(uuid)`.
- `start_job()` valida autenticación, rol, aprobación, estado de cuenta, asignación, estado del job, cotización aceptada y snapshot económico.
