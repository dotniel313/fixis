# FIXIS PRO v1.10.5 — Admin Premium

## Objetivo

Cerrar la migración visual principal llevando el panel financiero administrativo
al mismo sistema premium FIXIS ya validado en profesional y cliente.

## Incluye

- AppBar administrativo azul midnight + naranja.
- Marca FIXIS PRO integrada.
- Tabs premium:
  - Verificar
  - Historial
  - Liquidaciones
  - Ingresos FIXIS
- Conciliación con tarjetas y estados semánticos.
- Historial de pagos con chips PAGADO / RECHAZADO.
- Liquidaciones con superficies premium sin alterar acciones.
- Ingresos FIXIS con hero financiero, métricas y auditoría.
- Comisiones por servicio con trazabilidad visual mejorada.
- Diálogos de pago/rechazo alineados al design system.

## Backend

**NO requiere SQL.**

No se modifica:
- `admin_payments_repository.dart`
- RPCs de conciliación
- RPCs de settlements
- auditoría de ledger
- `admin_get_platform_revenue_summary`
- `admin_get_platform_commission_entries`
- RLS
- pagos
- ledger
- settlements

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación mínima

1. Entrar como admin.
2. Revisar pestaña Verificar.
3. Abrir voucher y confirmar que funciona.
4. Revisar Historial.
5. Revisar Liquidaciones.
6. Revisar Ingresos FIXIS.
7. Confirmar que el saldo contable conserva los mismos valores.
8. No ejecutar una nueva liquidación/pago salvo que quieras probar una operación real.
