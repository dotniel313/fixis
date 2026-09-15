# CHANGELOG v1.8.6

## Added
- `RouteService` desacoplado.
- `OsrmRouteService` con geometría GeoJSON.
- polyline de ruta en mapa del cliente.
- ETA aproximado y distancia vial.
- fallback no bloqueante si routing no responde.
- throttling de recálculo por movimiento/edad de estimación.

## Unchanged
- Supabase schema/RLS/RPCs.
- Financial Core.
- matching PostGIS.
- tracking Realtime.
- state machine.

## Status
Pendiente `flutter analyze` y validación en dos dispositivos.
