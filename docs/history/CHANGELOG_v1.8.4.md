# Changelog — v1.8.4

- Añadido `startRoute`, `updateLiveLocation` y `markArrived` al repositorio de jobs.
- Añadidos estados `en_route` y `arrived` a jobs activos y etiquetas de UI.
- `authorized` ahora inicia trayecto, no el servicio directamente.
- Tracking GPS en primer plano con Geolocator.
- `arrived` habilita `start_job()`.
- Cliente escucha `jobs` y `professional_live_locations` vía Realtime.
- Tarjeta FIXIS Live con coordenadas, precisión, hora y estado de sharing.
- Sin cambios de base de datos: requiere Migration 016 ya aplicada.
