# TEST E2E — v1.9.1 Admin Payment Reconciliation

## Preparación
1. Migration 020 aplicada.
2. `VALIDATE_020.sql` correcto.
3. Un usuario de prueba con `profiles.role = admin`.
4. Debe existir al menos un pago `pending_verification`.

## Admin
1. Iniciar sesión con el usuario admin.
2. AuthGate debe abrir `FIXIS Admin · Pagos`.
3. Debe aparecer el pago pendiente.
4. `Ver voucher` debe abrir la imagen desde el bucket privado.
5. Confirmar manualmente en el banco que el dinero llegó.
6. Pulsar `Confirmar acreditación`.
7. Registrar, si existe, ID/ref bancaria.

Esperado:
- payment -> paid
- payment_reconciliation -> confirmed
- payment_allocations creada
- job -> customer_approved
- financial_ledger_entries:
  - professional_earning
  - platform_commission

## Rechazo
1. Generar otro pago pendiente.
2. Admin pulsa Rechazar.
3. Ingresar motivo.
4. Esperado:
   - payment -> rejected
   - cliente puede volver a subir voucher.

## Seguridad
1. Iniciar sesión como customer/professional.
2. No debe entrar a AdminPaymentsScreen.
3. Intentar `admin_verify_bank_transfer` desde una sesión no admin.
4. Esperado: `ADMIN_REQUIRED`.
5. Confirmar que `verify_bank_transfer_trusted` sigue sin EXECUTE para authenticated.
