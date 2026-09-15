# TEST CHECKLIST — FIXIS PRO v1.4.2

- [ ] `flutter analyze` no introduce errores nuevos.
- [ ] Abrir un job en estado `work_completed`.
- [ ] Verificar que “Esperando confirmación del cliente” aparezca una sola vez.
- [ ] Pull-to-refresh mantiene una sola tarjeta.
- [ ] El job continúa visible en “Mis servicios activos”.
- [ ] No cambia el estado del job al navegar o refrescar.
- [ ] No se crean entradas nuevas en `financial_ledger_entries` antes de aprobación del cliente.
