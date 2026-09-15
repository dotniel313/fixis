# FIXIS PRO v1.1.1 — Fast Login & Dashboard

Fecha: 08-09-2026

## Objetivo
Reducir la demora percibida después de validar el OTP y antes de mostrar el Dashboard, sin quitar controles de seguridad.

## Cambios
- Se crea `getAccessProfile()` con una consulta mínima: `id`, `full_name`, `role`, `verification_status`, `account_status`.
- `evaluateProfessionalAccess()` deja de cargar el perfil completo durante el login.
- Se añade caché en memoria de la decisión de acceso por usuario.
- `professionalAccessProvider` deja de usar `autoDispose` durante la sesión.
- Después de verificar OTP se valida acceso una sola vez y el Auth Gate reutiliza ese resultado.
- `signOut()` limpia la caché de autorización.
- El botón "Volver a comprobar" fuerza una validación limpia.

## Sin cambios
- No se modifican RLS.
- No se modifican RPC.
- No se modifica Supabase.
- No se eliminan validaciones de rol, verificación o estado de cuenta.

## Bitácora
- PERF-001: demora después de OTP — corregido mediante consulta mínima + caché.
- PERF-002: segunda espera antes del Dashboard — reducido evitando segunda consulta de autorización.
