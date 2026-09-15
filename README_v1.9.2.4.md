# FIXIS PRO v1.9.2.4 — Platform Revenue Dashboard & Audit

## Objetivo

Dar visibilidad al dinero que pertenece a FIXIS.

La fuente de verdad sigue siendo el ledger:

- Cuenta: `FIXIS_REVENUE_USD`
- Tipo: `platform_revenue`
- Movimiento: `platform_commission`

No se crea una billetera paralela.

## Nueva pestaña Admin: FIXIS

Muestra:

- Saldo contable FIXIS
- Comisiones del mes
- Comisiones históricas
- Número de servicios
- Comisiones verificadas / por revisar
- Detalle por servicio:
  - total
  - mano de obra
  - materiales
  - comisión %
  - comisión FIXIS
  - monto profesional

## Auditoría

Cada `platform_commission` se compara contra
`job_financial_snapshots.commission_amount`.

También se comprueba que exista un único registro de comisión por
`job_id + snapshot_id`.

## Alcance contable

El saldo actual representa ingresos de comisión registrados en el ledger.
Todavía NO descuenta:

- impuestos;
- fees bancarios;
- fees de pasarela;
- gastos operativos;
- retiros/distribuciones de FIXIS.

Esos conceptos deben modelarse como una fase posterior, no restarse manualmente.

## Instalación

1. Ejecutar Migration 025.
2. Ejecutar `docs/VALIDATE_025.sql`.
3. Reemplazar `lib/` completa.
4. Ejecutar:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```
