# Checklist FIXIS PRO v1.3.0

## Backend
- [ ] Ejecutar `008_start_job_v1_3_0.sql`.
- [ ] Confirmar `start_job | DEFINER`.
- [ ] Confirmar que la cotización de prueba está `accepted`.
- [ ] Confirmar que el job está `authorized`.
- [ ] Confirmar que existe `job_financial_snapshots` para el job.

## Flutter
- [ ] `flutter analyze` sin errores.
- [ ] Abrir "Mis servicios activos".
- [ ] Abrir el job autorizado.
- [ ] Deslizar para refrescar si estaba abierto antes de la aprobación.
- [ ] Ver "Cotización aprobada".
- [ ] Ver total del servicio correcto.
- [ ] Ver comisión FIXIS correcta.
- [ ] Ver "Tu ingreso" correcto.
- [ ] Pulsar "Iniciar servicio".
- [ ] Confirmar snackbar verde.
- [ ] Confirmar `jobs.status = in_progress`.
- [ ] Confirmar que wallet no cambia.

## Caso de prueba esperado
Cotización: labor 30, materiales 15, otros 5.
- Servicio: $50.00
- Comisión FIXIS: $4.50
- Tu ingreso: $45.50
