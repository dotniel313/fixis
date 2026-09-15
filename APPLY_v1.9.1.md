# APLICACIÓN SEGURA — v1.9.1

Este paquete contiene `lib/` COMPLETA.

## 1. Backend
Ejecuta:
`supabase/migrations/020_admin_payment_reconciliation_v1_9_1.sql`

Después:
`docs/VALIDATE_020.sql`

## 2. Crear admin de prueba
Usa:
`docs/CONFIGURE_TEST_ADMIN.sql`

No conviertas al cliente/profesional que usas para las pruebas E2E;
usa una tercera cuenta de prueba.

## 3. Flutter
Haz backup de tu lib actual:

```bash
mv lib lib_backup_v1_9_0_2
```

Copia la `lib/` COMPLETA de este paquete.

Luego:

```bash
flutter clean
flutter pub get
flutter analyze
```

## 4. No ejecutar de nuevo
No vuelvas a ejecutar 018 ni 019.
