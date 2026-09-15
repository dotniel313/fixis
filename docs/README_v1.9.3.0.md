# FIXIS PRO v1.9.3.0 — Professional Wallet Foundation

## Cambio operativo

La billetera profesional se alinea al modelo definitivo:

`Disponible → corte semanal viernes → reservado → procesamiento → pagado`

Ya no se presenta como acción principal "Solicitar retiro".

## Compatibilidad

Los RPC legacy `request_withdrawal` y `cancel_withdrawal` no se eliminan.
Las solicitudes manuales históricas siguen visibles y pueden cancelarse
solo si siguen en `requested`.

Las liquidaciones semanales creadas por FIXIS tienen `generated_by != null`
y no pueden cancelarse desde la UI del profesional.

## Wallet muestra

- saldo disponible;
- saldo reservado;
- total ganado;
- total retirado;
- próximo corte de viernes;
- liquidación activa;
- fecha programada;
- historial;
- referencia bancaria cuando el pago ya fue realizado.

## Zona horaria

El calendario semanal se calcula en `America/Guayaquil`.

## Instalación

1. Ejecuta `026_professional_wallet_weekly_payout_v1_9_3_0.sql`.
2. Ejecuta `docs/VALIDATE_026.sql`.
3. Sustituye la `lib/` completa.
4. Ejecuta:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```
