# FIXIS PRO v1.8.4 — Flutter FIXIS Live Tracking

## Alcance
Integra Flutter con la Migration 016 ya validada.

### FIXI
- `authorized` → botón **Ir al cliente**.
- Obtiene GPS y llama `start_route()`.
- Estado `en_route` con FIXIS Live activo.
- Publica posición con `update_live_location()` por movimiento, con throttling mínimo de 5 s y `distanceFilter` de 15 m.
- Botón **Abrir navegación** para Waze/Google Maps/Apple Maps.
- Botón **Llegué** → `mark_arrived()` y detiene el stream GPS.
- Estado `arrived` → botón **Iniciar servicio** → `start_job()`.

### Cliente
- El detalle del job escucha cambios Realtime de `jobs`.
- En `en_route` muestra FIXIS Live y la última coordenada autorizada, precisión y hora de actualización.
- En `arrived` conserva la última posición y muestra que el tracking terminó.
- No hay mapa todavía; el mapa/FIXIS Pulse queda para v1.8.5.

## Privacidad
El GPS se comparte únicamente durante `en_route`. Se detiene en `arrived` y `in_progress`.

## Limitación conocida
v1.8.4 implementa tracking en primer plano dentro del detalle del trabajo. Si el FIXI cierra esa pantalla o el sistema suspende la app, el stream deja de publicar. El tracking en segundo plano se abordará más adelante con permisos y servicios específicos de plataforma.
