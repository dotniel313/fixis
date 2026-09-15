# FIXIS PRO v1.1.0 — Roles & Professional Status

## Cambios
- El login OTP ya no crea usuarios nuevos desde la app PRO (`shouldCreateUser: false`).
- Se agregó un Auth Gate que valida `role`, `verification_status` y `account_status`.
- Se agregaron pantallas para pendiente, rechazado, suspendido, bloqueado, rol incorrecto y perfil ausente.
- `acceptJob()` ahora utiliza `public.accept_job()` y ya no actualiza `jobs` directamente.
- `completeJob()` utiliza `public.complete_job_v1()` como RPC de compatibilidad segura.
- Se mapearon errores backend a mensajes legibles en Flutter.
- El Dashboard abre el `JobDetailScreen` con la fila realmente devuelta por `accept_job()`.

## Seguridad
- La app PRO no puede registrar usuarios OTP nuevos por sí sola.
- La autorización profesional se valida tanto al entrar como al ejecutar acciones críticas.
- No se reabre `UPDATE` sobre `jobs` para `authenticated`.

## Pendiente para v1.2+
- `complete_job_v1()` es una función de compatibilidad. No libera dinero ni genera comisión.
- El flujo completo de estados se implementará posteriormente.
- La categoría todavía es texto libre (`Plomería` / `Plomeria`).
