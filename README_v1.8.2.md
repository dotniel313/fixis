# FIXIS PRO v1.8.2 — Geo Creation Hotfix

Corrige la creación geográfica de solicitudes nuevas.

- `create_job()` exige `latitude` y `longitude`.
- Guarda ambas coordenadas en `jobs`.
- Construye `service_location` (PostGIS geography Point 4326) en el mismo INSERT.
- Evita crear nuevos jobs imposibles de descubrir mediante `get_nearby_jobs()`.

No modifica jobs históricos con coordenadas NULL.
