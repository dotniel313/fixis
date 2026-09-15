# FIXIS PRO v1.10.7.1 — Customer Avatar Hotfix

## Objetivo

Completar la identidad básica del cliente antes de Android/RC1.

## Cambios

- Foto de perfil real para cliente.
- Cámara o galería.
- Compresión de imagen antes de subir.
- Reutiliza `profiles.avatar_url`.
- Reutiliza el bucket `avatars_pro` que ya utiliza el perfil profesional.
- Indicador de carga integrado en el avatar.
- Refresco automático del perfil después de subir.

## Backend

No cambia jobs, pagos, tracking, ledger, settlements ni RPCs.

**No incluye SQL nuevo.**

Nota: esta entrega reutiliza el bucket existente. Si la política de Storage de tu
proyecto estuviera restringida exclusivamente al rol profesional, la UI mostrará
el error de Storage y habría que ampliar únicamente esa policy para clientes.

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba rápida iPhone

1. Cliente → Mi perfil.
2. Tocar avatar/cámara.
3. Probar cámara.
4. Confirmar que la foto queda visible.
5. Probar galería.
6. Salir y volver a entrar al perfil.
7. Confirmar persistencia del avatar.

## Estado posterior

Si pasa esta prueba: iOS queda cerrado y seguimos con Android físico.
