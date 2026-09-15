# FIXIS PRO v1.9.1.4 — Admin Payment RPC Fix

## Problema corregido

Al confirmar o rechazar un pago desde la app admin, PostgreSQL devolvía:

`invalid input syntax for type uuid: "(...)"`

La causa estaba en los wrappers creados en Migration 020.

Los RPC trusted retornan `public.payments`, que es un tipo compuesto. El wrapper usaba:

```sql
SELECT public.reject_bank_transfer_trusted(...)
INTO v_payment;
```

Eso hacía que PostgreSQL tratara el record completo como una única columna.

## Corrección

Ahora ambos wrappers usan:

```sql
SELECT *
INTO v_payment
FROM public.reject_bank_transfer_trusted(...);
```

y el equivalente para `verify_bank_transfer_trusted`.

## Qué NO cambia

- No cambia Flutter.
- No cambia RLS.
- No cambia Storage.
- No cambia el cálculo financiero.
- Los RPC trusted siguen sin estar disponibles para `authenticated`.
- El admin sigue validándose por `profiles.role = 'admin'` y `account_status = 'active'`.

## Aplicación

Ejecuta en Supabase SQL Editor:

`supabase/migrations/021_admin_payment_rpc_composite_fix_v1_9_1_4.sql`

Después vuelve a probar desde la app admin:
1. Rechazar un pago pendiente nuevo.
2. Confirmar otro pago pendiente.
3. Verificar que ambos pasan a Historial sin error rojo.

## Importante

El pago de $35 mostrado en la prueba anterior ya alcanzó estado `rejected` antes del error de conversión UUID. No es necesario rechazarlo otra vez.
