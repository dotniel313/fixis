# FIXIS PRO v1.3.0

Versión enfocada en mostrar al FIXI la aprobación de la cotización, el snapshot económico real y permitir el inicio seguro del servicio.

## Orden de instalación
1. Respaldar `lib` actual.
2. Ejecutar `supabase/migrations/008_start_job_v1_3_0.sql` en Supabase.
3. Copiar la carpeta `lib/` de esta entrega sobre la `lib/` del proyecto.
4. Copiar `docs/` y la migración a sus carpetas correspondientes.
5. Ejecutar:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Importante
Esta versión no genera earnings, pagos ni liquidaciones. El snapshot financiero es informativo y contractual; el ledger llegará en una versión posterior.
