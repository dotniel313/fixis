# FIXIS PRO v1.9.1 — Admin Payment Reconciliation

Esta entrega parte de la `lib/` completa validada de v1.9.0.2.

## Incluye
- Migration 020.
- Acceso Flutter para `role = admin`.
- Bandeja de pagos `pending_verification`.
- Visualización del voucher privado con URL firmada temporal.
- Confirmación de acreditación.
- Rechazo de comprobante.
- Historial reciente paid/rejected.
- Sin `service_role` en Flutter.

## No incluye todavía
- Automatización de liquidación semanal del viernes.
- Integración bancaria automática.
- Panel tributario.
- Pasarela de tarjeta.

La liquidación semanal será la fase siguiente, reutilizando
`settlements`, `settlement_items` y los RPC trusted existentes.
