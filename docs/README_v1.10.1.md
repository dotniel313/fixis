# FIXIS PRO v1.10.1 — Map-first Professional Home

## Cambios

- Elimina la duplicación visual de Billetera.
- La acción secundaria ahora es **Mi actividad**.
- Integra **Radar FIXIS** como mapa principal del dashboard profesional.
- Reutiliza `flutter_map`, OpenStreetMap y ubicación ya presentes en el proyecto.
- Visualiza:
  - ubicación actual del profesional;
  - radio de cobertura 5 / 8 / 15 / 25 km;
  - oportunidades con coordenadas cuando el RPC las entregue;
  - contador de oportunidades;
  - estado online/offline.
- Tocar un marcador de oportunidad abre una ficha rápida y permite aceptar el job.
- Nueva pantalla `Mi actividad` con servicios activos y métricas operativas básicas.

## Seguridad / backend

- **NO requiere SQL.**
- No modifica RLS.
- No modifica RPC.
- No modifica pagos, ledger, wallet, settlements o notificaciones.
- Si una oportunidad no trae coordenadas, simplemente no crea marcador; continúa
  apareciendo en la lista normal.

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba mínima

1. Entrar como FIXI.
2. Confirmar que arriba queda Billetera una sola vez.
3. Confirmar `Nivel FIXIS` + `Mi actividad`.
4. Con radar OFF debe verse el placeholder oscuro del mapa.
5. Activar radar.
6. Confirmar mapa + posición + círculo de cobertura.
7. Cambiar 5 / 8 / 15 / 25 km.
8. Abrir `Mi actividad`.
9. Confirmar que trabajos activos siguen disponibles.
