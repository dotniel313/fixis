# TEST CHECKLIST — v1.8.5.3

## Auth profesional
1. Abrir login.
2. Ingresar correo con mayúsculas/espacios; confirmar que el flujo sigue funcionando.
3. Solicitar OTP y medir tiempo hasta respuesta visual.
4. Confirmar contador 60 s y botón Reenviar deshabilitado.
5. Verificar con el código más reciente.
6. Solicitar nuevo OTP, luego intentar usar el código anterior: debe mostrar mensaje específico de código inválido/expirado.
7. Usar el nuevo código: debe iniciar sesión.

## Auth cliente
1. Crear una cuenta cliente.
2. Confirmar mismo cooldown y mensajes.
3. Verificar OTP y confirmar routing a Customer Home.

## Query / Realtime
1. Entrar como profesional.
2. Revisar Supabase Logs durante carga del dashboard.
3. Confirmar ausencia del error `P0001 invalid column for filter assigned_pro_id`.
4. Confirmar que el profesional solo ve jobs asignados y activos.
5. Confirmar que nuevas actualizaciones de sus jobs siguen llegando por Realtime.

## Comandos
```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

Criterio de salida: `flutter analyze` sin errores y pruebas Auth + Realtime exitosas.
