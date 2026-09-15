# FIXIS PRO v1.8.5 — Mapa Cliente + FIXIS Pulse

## Alcance

Esta versión convierte FIXIS Live en una vista geográfica para el cliente.

- Mapa de seguimiento durante `en_route`.
- Marcador FIXIS Pulse por categoría.
- Marcador del domicilio del servicio.
- Actualización del marcador desde `professional_live_locations` vía Realtime.
- Distancia geodésica aproximada entre FIXI y servicio.
- Última ubicación visible en `arrived`.
- Sin cambios de Supabase.
- Sin ruta vial ni ETA todavía; quedan para v1.8.6.

## Dependencias nuevas

Ejecutar desde la raíz del proyecto:

```bash
flutter pub add flutter_map:^8.3.2
flutter pub add latlong2:^0.10.1
```

Después:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Instalación

Respaldar el `lib` actual y reemplazarlo por el `lib` incluido en esta entrega.

```bash
cp -R lib lib_backup_v1.8.4
```

## Prueba funcional

1. Llevar un job con cliente real a `authorized`.
2. En FIXI pulsar `Ir al cliente`.
3. Abrir el mismo servicio en Cliente.
4. Debe mostrarse un mapa con:
   - FIXIS Pulse del profesional.
   - marcador de la dirección del servicio.
   - distancia aproximada.
   - hora y precisión de la última actualización.
5. Mover el FIXI unos metros y comprobar que el marcador cambia por Realtime.
6. Pulsar `Llegué`.
7. El mapa debe conservar la última posición y mostrar tracking detenido.

## Nota técnica

El mapa base usa OpenStreetMap mediante flutter_map. El tracking sigue siendo foreground-only, igual que v1.8.4.
