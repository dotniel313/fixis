# FIXIS PRO v1.9.2.0 — Weekly Settlements Backend

Esta fase instala el motor backend para el corte semanal de pagos a profesionales.

## Flujo

```text
professional_earning disponible
        ↓
corte semanal
        ↓
settlement requested
        ↓
processing
        ↓
paid
        ↓
settlement_debit en ledger
```

Si una liquidación se rechaza, sus `settlement_items` dejan de reservar saldo porque
`get_wallet_summary()` y el cálculo de disponible solo consideran `requested`,
`processing` y `paid`.

## Seguridad

Flutter NO ejecuta funciones trusted.

El cliente admin solo puede usar:

- `admin_create_weekly_settlements`
- `admin_mark_settlement_processing`
- `admin_mark_settlement_paid`
- `admin_reject_settlement`

Cada wrapper valida:

- `auth.uid()`
- perfil existente
- `role = admin`
- `account_status = active`

## Idempotencia del corte

Si el corte se ejecuta dos veces, la segunda ejecución no vuelve a asignar earnings
ya reservados, porque `settlement_items` se descuentan del disponible real.

## Viernes

Esta fase no instala `pg_cron`. Primero validaremos el motor con el Admin real.
Después podemos automatizar el disparo de cada viernes o mantener aprobación manual.

## Aplicación

Ejecuta:

`supabase/migrations/022_weekly_settlements_backend_v1_9_2_0.sql`

Después ejecuta:

`docs/VALIDATE_022.sql`

y comparte los resultados antes de conectar Flutter Admin.
