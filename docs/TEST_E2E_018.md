# Test E2E — Migration 018

## Caso 1 — Transferencia correcta

1. Crear trabajo.
2. FIXI acepta y cotiza.
3. Cliente acepta cotización.
4. FIXI completa el trabajo.
5. Confirmar `jobs.status = work_completed`.
6. Cliente ejecuta `prepare_job_payment(job_id, 'bank_transfer')`.
7. Esperado:
   - payment creado;
   - status `pending_transfer`;
   - amount = snapshot.gross_amount;
   - referencia `FIX-...`.
8. Cliente sube voucher y ejecuta `submit_bank_transfer_evidence`.
9. Esperado: `pending_verification`.
10. Confirmar que el job SIGUE `work_completed`.
11. Trusted backend verifica transferencia.
12. Ejecutar `verify_bank_transfer_trusted`.
13. Esperado:
   - payment `paid`;
   - allocation creada;
   - reconciliation `confirmed`;
   - job `customer_approved`;
   - ledger professional_earning;
   - ledger platform_commission.

## Caso 2 — Voucher falso / monto incorrecto

1. Payment pending_verification.
2. Intentar confirmar monto diferente a `total_due`.
3. Esperado: `PAYMENT_AMOUNT_MISMATCH`.
4. Job sigue `work_completed`.
5. No se crean earnings/comisiones.

## Caso 3 — Rechazo

1. Ejecutar `reject_bank_transfer_trusted`.
2. Payment pasa `rejected`.
3. Cliente puede volver a subir evidencia.
4. Payment vuelve `pending_verification`.

## Caso 4 — Intento de bypass

Como authenticated customer intentar:

```sql
select public.approve_completed_job('<job-id>');
```

Esperado: permiso denegado.

## Caso 5 — Idempotencia

Ejecutar dos veces `prepare_job_payment()` para el mismo job.

Esperado: retorna el mismo payment, no duplica registros.
