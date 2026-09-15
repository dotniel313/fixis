# FIXIS PRO v1.8.5.3 — Auth & Query Hotfix

Hotfix previo a continuar v1.8.6 Route + ETA.

No requiere migración SQL.

Cambios principales:
- OTP consistente para cliente/profesional.
- Email normalizado en envío/verificación.
- Cooldown 60 s y reenvío controlado.
- Mensajes Auth específicos.
- Instrumentación de latencia mediante `debugPrint`.
- Corrección de la suscripción Realtime que generaba P0001 en `assigned_pro_id`.

Validar primero con `flutter analyze`, luego hacer prueba real con profesional y cliente.
