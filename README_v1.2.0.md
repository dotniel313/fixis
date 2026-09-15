# FIXIS PRO v1.2.0

## Instalación

1. Respaldar la versión actual:

```bash
cp -R lib lib_backup_v1.1.2
```

2. Copiar la carpeta `lib/` de esta entrega sobre la `lib/` del proyecto.

3. Guardar:

- `docs/CHANGELOG_v1.2.0.md`
- `docs/TEST_CHECKLIST_v1.2.0.md`
- `supabase/migrations/006_quotes_foundation_v1_2_0.sql`

4. Si Migration 006 todavía no fue aplicada, ejecutar el SQL en Supabase SQL Editor. Si ya se aplicó la versión preliminar anterior, este archivo puede volver a ejecutarse para actualizar las RPC al comportamiento final v1.2.0.

5. Validar Flutter:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Flujo v1.2.0

`pending -> accepted -> draft quote -> quote_submitted`

No continuar manualmente a `in_progress`. La decisión del cliente se implementará en la siguiente evolución del marketplace.
