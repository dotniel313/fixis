# FIXIS PRO v1.8.6 RC2 — Test Checklist

## Build
- [ ] `flutter pub add http:^1.6.0`
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter analyze` = No issues found

## FIXIS Live
1. [ ] Usar un job nuevo ya autorizado o crear uno nuevo con coordenadas válidas.
2. [ ] Profesional pulsa `Ir al cliente`.
3. [ ] Job cambia a `en_route`.
4. [ ] Cliente abre detalle del trabajo.
5. [ ] Aparece FIXIS Pulse y destino.
6. [ ] Aparece polilínea sobre calles.
7. [ ] Aparece `≈ X min · Y km/m`.
8. [ ] Mover profesional >= 80 m; comprobar actualización posterior de ruta/ETA.
9. [ ] Profesional pulsa `Llegué`.
10. [ ] Job cambia a `arrived` y deja de compartir activamente.
11. [ ] Cliente conserva última ubicación y ya no muestra ETA activo.
12. [ ] Profesional inicia servicio y flujo continúa a `in_progress`.

## Regression
- [ ] No aparece `P0001 invalid column for filter assigned_pro_id`.
- [ ] Login/OTP sigue funcionando como en v1.8.5.3.
- [ ] Cotización, aprobación, finish, customer approval y wallet siguen funcionando.

## Fallback
- [ ] Si OSRM no responde, el mapa sigue visible y muestra distancia aproximada; la app no se cae.
