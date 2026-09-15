# FIXIS PRO v1.8.1 — Flutter Geo Matching

Esta entrega conecta Flutter con la infraestructura PostGIS ya instalada mediante Migration 014.

## Profesional
- El switch En línea sincroniza disponibilidad y GPS con `update_professional_presence()`.
- Radio seleccionable: 5, 8, 15 o 25 km.
- El radar consulta `get_nearby_jobs()`; ya no lee todos los `jobs pending` directamente.
- Cada oportunidad muestra distancia en km.
- La aceptación usa exclusivamente `accept_nearby_job()`.

## Cliente
- Crear solicitud requiere confirmar la ubicación del servicio mediante GPS.
- `create_job()` recibe latitude/longitude reales junto con la dirección escrita.
- Los trabajos nuevos ya pueden participar en matching PostGIS.

## Backend requerido
Migration 014 — Geo Matching Foundation debe estar aplicada. Se considera validada cuando:
- PostGIS está instalado.
- `update_professional_presence`, `get_nearby_jobs`, `accept_nearby_job` son SECURITY DEFINER.
- `authenticated` no tiene EXECUTE sobre `accept_job`.

## Alcance
Esta versión NO implementa todavía seguimiento en vivo. FIXIS Live / en_route / arrived / mapa cliente corresponde a la siguiente fase.
