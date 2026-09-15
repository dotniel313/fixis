# FIXIS PRO v1.9.1.3.1 — Admin Dialog Build Fix

## Qué corrige

La versión v1.9.1.3 eliminó accidentalmente cuatro helpers del archivo
`admin_payments_screen.dart` al reemplazar el bloque de diálogos:

- `_field`
- `_empty`
- `_toDouble`
- `_money`

Esto provocaba errores Dart y terminaba reportándose desde Xcode como:

`Command PhaseScriptExecution failed with a nonzero exit code`

## Esta versión conserva

- ADMIN-UI-001: diálogos sin TextEditingController problemáticos
- AUTH-LINT-001: `await ref.refresh(appAccessProvider.future)`
- Todas las correcciones de v1.9.1.2
- Auth admin v1.9.1.1

## Backend

No requiere SQL.
No modifica Supabase.
No modifica Payments.
No modifica Storage.

## Aplicación

El ZIP contiene la `lib/` completa.

```bash
mv lib ../lib_backup_v1_9_1_3
# Copiar la lib/ completa de este paquete
flutter clean
flutter pub get
flutter analyze
flutter run
```

Esperado:

`No issues found!`
