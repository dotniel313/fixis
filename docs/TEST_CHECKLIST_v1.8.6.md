# TEST CHECKLIST — FIXIS PRO v1.8.6

## Compile
- [ ] `flutter pub add http:^1.6.0`
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter analyze` → No issues found

## E2E Route + ETA
- [ ] Cliente crea job con GPS.
- [ ] FIXI acepta y envía cotización.
- [ ] Cliente acepta cotización.
- [ ] FIXI pulsa “Ir al cliente”.
- [ ] Job pasa a `en_route`.
- [ ] Cliente ve FIXIS Pulse.
- [ ] Cliente ve destino.
- [ ] Se dibuja polyline vial.
- [ ] Aparece ETA aproximado.
- [ ] Aparece distancia por carretera.
- [ ] Mover dispositivo FIXI > 80 m actualiza ruta/ETA.
- [ ] Si routing falla, tracking Live no se cae.
- [ ] FIXI pulsa “Llegué”.
- [ ] Job pasa a `arrived`.
- [ ] ETA/ruta dejan de presentarse como trayecto activo.
- [ ] Iniciar servicio desde `arrived` sigue funcionando.

## Regression
- [ ] Quotes funcionan.
- [ ] Customer approval funciona.
- [ ] Ledger genera earning/commission una sola vez.
- [ ] Wallet mantiene saldo correcto.
