# FIXIS PRO — Error Log v1.8.5.3

| ID | Área | Hallazgo | Estado |
|---|---|---|---|
| AUTH-004 | Auth | OTP llega tarde, códigos anteriores pueden terminar inválidos/expirados y la app ocultaba el error real | Corregido en código / pendiente validación real |
| DB-006 | Realtime | `P0001 invalid column for filter assigned_pro_id` al suscribir stream de jobs | Mitigado eliminando filtro Realtime / pendiente validación real |
| PERF-001 | Auth | Latencia de entrega de email OTP | Abierto: requiere medir Auth/SMTP; el hotfix instrumenta tiempo de llamada de app a Supabase |
