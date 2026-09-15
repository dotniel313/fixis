# FIXIS PRO v1.9.2.3 — Settlement Audit & Traceability

## Objetivo

Cerrar la etapa de liquidaciones con una comprobación contable visible para Admin.

Para cada liquidación se valida:

- monto solicitado;
- suma de `settlement_items`;
- cantidad de `settlement_debit`;
- monto debitado del ledger;
- estado final;
- referencia bancaria.

## Estados de auditoría

- `Ledger verificado`: paid + 1 solo debit + montos cuadrados.
- `Saldo reservado`: requested/processing + allocations completas + sin debit.
- `Cerrada sin débito`: rejected/cancelled sin debit.
- `Revisar auditoría`: inconsistencia que requiere revisión.

## Seguridad

La app usa `admin_get_settlement_audit()`.
La función valida `auth.uid()`, `role=admin` y `account_status=active`.

No se exponen funciones trusted al cliente.

## Instalación

1. Ejecutar:
   `supabase/migrations/024_admin_settlement_audit_v1_9_2_3.sql`

2. Validar:
   `docs/VALIDATE_024.sql`

3. Reemplazar la `lib/` completa.

4. Ejecutar:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba esperada

Una liquidación `paid` correcta debe mostrar:

- Estado: Pagada
- Referencia: ...
- Asignado: mismo monto
- Débito ledger: `1 · $monto`
- `Ledger verificado`
