# FIXIS PRO v1.8.6 — Route + ETA

Estado: candidate / pendiente de validación en dispositivo.
Base: v1.8.5.2 Stabilization + migration baseline 001–017.

## Objetivo
Durante `en_route`, el cliente ve:
- FIXIS Pulse en Realtime.
- destino del servicio.
- ruta vial dibujada como polyline.
- distancia por carretera.
- ETA aproximado.

## Arquitectura
El mapa continúa con `flutter_map` + tiles OpenStreetMap.
El cálculo de ruta está desacoplado mediante `RouteService`.
La implementación inicial es `OsrmRouteService` para desarrollo/pruebas.

Esto evita acoplar la UI a un proveedor. En producción se puede sustituir por
Mapbox Directions, Google Routes o un OSRM propio sin reescribir la pantalla.

## Política de refresco
No se solicita ruta en cada paquete GPS. Se recalcula cuando:
- el FIXI se mueve >= 80 m, o
- el destino cambia >= 20 m, o
- la estimación supera 45 s.

Timeout de routing: 8 s. Si falla, FIXIS Live sigue funcionando y se muestra
distancia geodésica como fallback sin bloquear el servicio.

## Archivos nuevos
- `lib/core/services/route_service.dart`

## Archivos modificados
- `lib/features/customer/screens/customer_job_detail_screen.dart`

## Dependencia nueva
```bash
flutter pub add http:^1.6.0
```

`flutter_map` y `latlong2` ya pertenecen al mapa v1.8.5.

## IMPORTANTE
`router.project-osrm.org` se usa como endpoint de desarrollo. Antes de producción
se debe escoger un proveedor con SLA/capacidad adecuada o desplegar OSRM propio.
