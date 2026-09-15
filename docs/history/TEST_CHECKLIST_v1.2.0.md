# FIXIS PRO v1.2.0 — Checklist de pruebas

## A. Base de datos
- [ ] Existe tabla `quotes`.
- [ ] Existe columna `jobs.accepted_quote_id`.
- [ ] `accept_job`, `create_quote`, `submit_quote` son `SECURITY DEFINER`.
- [ ] `quotes` tiene RLS activa.
- [ ] `authenticated` solo tiene SELECT directo sobre `quotes`.

## B. Compilación
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter run`

## C. Aceptar oportunidad
- [ ] Crear/usar un job nuevo con status `pending`.
- [ ] Activar radar.
- [ ] Aceptar oportunidad.
- [ ] El job cambia a `accepted`.
- [ ] Abre `JobDetailScreen`.
- [ ] Ya no aparece el botón de completar trabajo inmediatamente.

## D. Cotización
- [ ] Pulsar `Preparar cotización`.
- [ ] Ingresar mano de obra.
- [ ] Ingresar materiales.
- [ ] Ingresar otros.
- [ ] El total visual se actualiza.
- [ ] Guardar borrador funciona.
- [ ] El registro en Supabase queda `draft`.
- [ ] Enviar cotización funciona.
- [ ] Quote cambia a `submitted`.
- [ ] Job cambia a `quote_submitted`.
- [ ] Se muestra `Esperando aprobación del cliente`.

## E. Seguridad / reglas
- [ ] Total 0 es rechazado.
- [ ] Monto negativo es rechazado.
- [ ] Una quote `submitted` no puede volver a editarse con `create_quote()`.
- [ ] Otro FIXI no puede ver la cotización.
- [ ] No se genera ningún `wallet_transaction` al enviar cotización.

## F. Dashboard
- [ ] Un job `accepted` aparece en `Mis servicios activos`.
- [ ] Un job `quote_submitted` aparece en `Mis servicios activos`.
- [ ] El servicio activo sigue visible aunque el radar esté OFF.
- [ ] Un job aceptado deja de aparecer en `Nuevas oportunidades`.

## G. Regresión
- [ ] Login funciona.
- [ ] Perfil funciona.
- [ ] Wallet abre.
- [ ] Gamificación abre.
- [ ] Radar recibe jobs pending.
