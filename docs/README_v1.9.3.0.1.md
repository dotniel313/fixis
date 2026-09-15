# FIXIS PRO v1.9.3.0.1 — Auth Resilience

Hotfix preventivo posterior al incidente AUTH-002.

## Qué cambia

- Detecta explícitamente `504 upstream request timeout`.
- Explica al usuario que el OTP aún puede llegar.
- Inicia el cooldown de 60 s ANTES de esperar la respuesta de Supabase.
- Bloquea solicitudes paralelas de OTP.
- Un timeout no habilita un reintento inmediato.
- Mantiene intactos Wallet, pagos, ledger y settlements.

## Qué NO cambia

- No hay migración SQL.
- No cambia el método OTP.
- No cambia `verifyOTP`.
- No cambia AuthGate ni RLS.
- No se cierra ninguna sesión automáticamente durante `sendOtp`.

## Aplicación

Reemplazar la carpeta `lib/` completa del paquete.

Luego:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba

1. Solicitar un OTP una sola vez.
2. Confirmar que el botón queda bloqueado 60 segundos.
3. Si el SMTP devuelve 504, verificar que NO sea posible disparar inmediatamente otro envío.
4. Ingresar con el código más reciente.
