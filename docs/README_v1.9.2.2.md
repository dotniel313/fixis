# FIXIS PRO v1.9.2.2 — Settlement Professional Name

## Mejora

La pestaña Liquidaciones deja de mostrar el UUID del profesional y muestra su nombre.

Antes:
`f38b02ca-a178-4763-9473-798f5659fff8`

Ahora:
`Nombre del profesional`

## Diseño

Se agrega `settlements.professional_name` como snapshot histórico.

Esto es mejor que abrir SELECT amplio sobre `profiles` porque:

- el Admin no necesita acceso directo a todos los perfiles;
- el nombre queda congelado con la liquidación;
- las liquidaciones antiguas se rellenan con un backfill;
- las nuevas se completan automáticamente mediante trigger.

## Aplicación

1. Ejecuta:
   `supabase/migrations/023_settlement_professional_name_v1_9_2_2.sql`

2. Ejecuta:
   `docs/VALIDATE_023.sql`

3. Sustituye la `lib/` completa de este paquete.

4. Ejecuta:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

No cambia el motor financiero ni el cálculo de liquidaciones.
