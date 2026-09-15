# FIXIS PRO v1.10.0 — Premium Design System + Identidad

## Alcance

Primera entrega de la fase premium.

### Incluye

- Design tokens semánticos de FIXIS:
  - naranja de marca
  - azul funcional
  - midnight premium
  - estados success / warning / danger
  - superficies, bordes, radios y sombras
- Theme Material 3 renovado.
- Jerarquía tipográfica Inter.
- Componentes reutilizables:
  - `FixisBrandMark`
  - `FixisSurface`
  - `FixisIconButton`
  - `FixisSectionHeader`
  - `FixisStatusPill`
- Dashboard profesional con:
  - cabecera premium oscura
  - marca FIXIS PRO
  - avatar y accesos rápidos
  - radar integrado visualmente
  - acciones Nivel FIXIS / Billetera
  - tarjetas y secciones más consistentes
  - notificaciones preservadas
- No altera jobs, pagos, ledger, wallet, settlements, RLS ni RPCs.

## SQL

**NO requiere SQL.**

## Aplicación

Reemplazar `lib/` completa.

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación visual mínima

1. Login profesional.
2. Confirmar cabecera FIXIS PRO premium.
3. Abrir Wallet y volver.
4. Abrir Notificaciones y volver.
5. Abrir Nivel FIXIS y volver.
6. Activar/desactivar Radar.
7. Revisar trabajos activos y oportunidades.

## Próximo paso

`v1.10.1 — Map-first Professional Home`

La siguiente entrega convertirá el mapa/radar en una pieza central del dashboard
reutilizando la infraestructura FIXIS Live + PostGIS + OSRM ya validada.
