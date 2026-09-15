# TEST — v1.9.0 Flutter Payment Flow Phase 1

## A. Preparación
- Migration 018 validada.
- Migration 019 aplicada.
- Bucket `payment-evidence` privado.
- Una cuenta bancaria activa en `payment_bank_accounts`.
- `flutter analyze` sin errores.

## B. Cliente
1. Crear y completar un trabajo hasta `work_completed`.
2. Debe aparecer `Aprobar y pagar`.
3. Abrir pantalla de pago.
4. Ver desglose de la cotización.
5. Tarjeta debe mostrarse `Próximamente`.
6. Seleccionar transferencia.
7. Debe crearse un `payment` con:
   - method `bank_transfer`
   - status `pending_transfer`
   - reference_code `FIX-...`
8. Deben mostrarse los datos bancarios configurados.
9. Seleccionar voucher desde galería.
10. Enviar.
11. Debe pasar a `pending_verification`.
12. Job DEBE seguir `work_completed`.

## C. Seguridad
- El voucher debe quedar en bucket privado.
- La ruta debe comenzar:
  `<customer_uid>/<payment_id>/...`
- Otro cliente no debe poder consultar ni subir en esa ruta.
- El cliente no debe poder ejecutar `approve_completed_job()`.

## D. Conciliación backend
1. Verificar realmente la transferencia.
2. Ejecutar `verify_bank_transfer_trusted()` desde entorno trusted.
3. Esperado:
   - payment `paid`
   - reconciliation `confirmed`
   - allocation creada
   - job `customer_approved`
   - ledger profesional + comisión FIXIS.

## E. Rechazo
1. Usar `reject_bank_transfer_trusted()`.
2. Cliente debe ver `Pago rechazado`.
3. Debe poder subir un nuevo voucher.
