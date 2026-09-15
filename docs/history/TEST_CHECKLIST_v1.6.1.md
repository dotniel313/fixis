# Test Checklist — FIXIS PRO v1.6.1

## Auth
- [ ] FIXI existente inicia sesión y llega a Dashboard profesional.
- [ ] Cliente nuevo pulsa "Soy cliente: crear cuenta".
- [ ] OTP crea `profiles.role = customer` y `account_status = active`.
- [ ] Cliente llega a Home Cliente.

## Job
- [ ] Cliente crea solicitud.
- [ ] DB: `client_id = auth.uid()`.
- [ ] DB: `status = pending`.
- [ ] DB: `assigned_pro_id IS NULL`.
- [ ] Profesional ve la nueva oportunidad.

## Quote / Approval
- [ ] FIXI acepta trabajo y envía cotización.
- [ ] Cliente ve cotización en su detalle.
- [ ] Cliente acepta cotización.
- [ ] Job pasa a `authorized`.
- [ ] FIXI inicia y finaliza trabajo.
- [ ] Cliente ve `work_completed`.
- [ ] Cliente confirma servicio.
- [ ] Job pasa a `customer_approved`.
- [ ] Ledger crea earning + comisión una sola vez.
