# FIXIS PRO v1.9.1.1 — Admin Auth Hotfix

## Problema

Después de validar correctamente el OTP del usuario admin, AuthGate mostraba:

`No pudimos validar tu acceso`

El perfil en Supabase era correcto:

- Auth UUID == profile UUID
- role = admin
- account_status = active
- verification_status = approved
- RLS profiles_select_own correcto
- authenticated tiene SELECT

## Causa probable corregida

`getAccessProfile()` pedía:

`id, full_name, role, verification_status, account_status`

aunque `full_name` no es necesario para decidir acceso.

Si PostgREST no podía resolver uno de esos campos, el código anterior hacía:

`catch (_) { return null; }`

y ocultaba por completo la causa.

## Cambios

- AuthGate consulta únicamente:
  - id
  - role
  - verification_status
  - account_status
- Los errores PostgREST ya no se convierten silenciosamente en null.
- Se imprimen datos de diagnóstico `[AUTH]` en consola.
- `Volver a comprobar` limpia cache y fuerza `ref.refresh(appAccessProvider)`.

## Aplicación

Este paquete contiene `lib/` COMPLETA.

Haz backup:

```bash
mv lib ../lib_backup_v1_9_1
```

Copia la `lib/` completa de este paquete.

Luego:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

No ejecutar SQL adicional.
