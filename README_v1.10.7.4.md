# FIXIS PRO v1.10.7.4 — Customer Header Alignment

## Objetivo

Unificar visualmente Cliente y FIXI.

## Cambios

- Avatar real del cliente en el encabezado premium.
- Tocar avatar abre `CustomerProfileScreen`.
- Si no existe foto, se muestra icono de usuario.
- Se elimina la tarjeta redundante `Mi perfil`.
- Se mantiene saludo y CTA principal.
- Se conserva foto de perfil con cámara/galería.
- Se conserva eliminación de cuenta.
- Se conserva todo el flujo de jobs, pagos y tracking.

## SQL

**NO requiere SQL.**

## Aplicación

Reemplazar la `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación

1. Entrar como cliente.
2. Ver avatar arriba a la derecha.
3. Tocar avatar.
4. Confirmar que abre Mi perfil.
5. Cambiar foto.
6. Volver al Home.
7. Confirmar que el avatar nuevo aparece en la cabecera.
