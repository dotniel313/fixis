# FIXIS PRO v1.8.6 RC2 — FIXIS Live Route + ETA

Base: v1.8.5.3 Auth & Query Hotfix validado E2E.

## Incluye
- FIXIS Live Realtime existente.
- FIXIS Pulse del profesional.
- Ruta vial mediante `RouteService` desacoplado.
- Proveedor de desarrollo: OSRM.
- Polilínea de ruta en el mapa del cliente.
- Distancia vial y ETA aproximado.
- Recalculo controlado: movimiento >= 80 m, cambio destino >= 20 m o ruta >= 45 s.
- Fallback seguro a distancia geodésica si el proveedor de rutas falla.
- Conserva hotfix Auth v1.8.5.3.
- Conserva fix de Realtime: sin filtro servidor `.eq('assigned_pro_id', ...)`.

## Dependencia nueva
```bash
flutter pub add http:^1.6.0
```
`flutter_map` y `latlong2` deben permanecer instalados desde v1.8.5.

## No requiere migración SQL
No ejecutar nuevamente `supabase/migrations/` sobre la base actual.

## Estado
Release candidate. Validar en dispositivo antes de marcar v1.8.6 estable.
