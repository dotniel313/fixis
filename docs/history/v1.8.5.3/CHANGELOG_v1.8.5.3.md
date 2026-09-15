# FIXIS PRO v1.8.5.3 — Auth & Query Hotfix

## AUTH-004 — OTP reliability / diagnostics
- Normaliza email con `trim().toLowerCase()` para envío y verificación.
- Conserva `OtpType.email` y el mismo email normalizado en `verifyOTP`.
- Expone mensajes específicos para OTP expirado, rate limit, usuario inexistente y token inválido.
- Registra tiempos de `sendOtp` / `verifyOtp` mediante `debugPrint`, sin imprimir el OTP ni el correo completo.
- Agrega cooldown de reenvío de 60 segundos.
- Al reenviar, limpia el código anterior y avisa usar únicamente el último correo.
- Cliente y profesional comparten la misma lógica segura de AuthRepository.

## DB-006 — Realtime `assigned_pro_id` P0001
- Retirado el filtro Realtime `.eq('assigned_pro_id', user.id)` de `myActiveJobsStreamProvider`.
- Seguridad se mantiene por RLS de `jobs_select_for_professional`.
- Se conserva filtro local adicional por `assigned_pro_id` y estados activos.

## Sin cambios
- No modifica Supabase schema.
- No modifica Route/ETA v1.8.6.
- No cambia comisión, ledger, wallet, settlements ni FIXIS Live.
