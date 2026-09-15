# FIXIS PRO v1.10.4 — Customer Premium Experience

## Objetivo

Llevar la experiencia cliente al mismo lenguaje visual premium ya validado
en el profesional, sin alterar el flujo transaccional.

## Customer Home

- Cabecera FIXIS premium azul midnight + naranja.
- Saludo personalizado.
- CTA claro para solicitar servicio.
- Servicios activos con chips visuales por estado.
- Historial separado y más legible.
- Estados importantes resaltados:
  - Buscando FIXI
  - Cotización
  - En camino
  - En curso
  - Confirmación pendiente
  - Confirmado

## Nuevo servicio

- Formulario reorganizado por:
  - Servicio
  - Ubicación
- GPS visualmente integrado.
- Mantiene las mismas categorías y validaciones.
- Mantiene el mismo `createJob()` y coordenadas reales.

## Detalle del servicio

- Adopta superficies y cabecera FIXIS premium.
- FIXIS Live, ruta y ETA se conservan.
- Cotizaciones y acciones se presentan con el sistema visual compartido.
- No se altera aceptación de cotización, pago ni tracking.

## Backend

**NO requiere SQL.**

No cambia:
- customer_repository
- jobs
- quotes
- payments
- FIXIS Live
- OSRM
- RLS
- RPCs

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación mínima

1. Entrar como cliente.
2. Confirmar home premium.
3. Abrir un servicio activo y verificar detalle.
4. Confirmar mapa/tracking si el job está en `en_route`.
5. Volver.
6. Crear una solicitud nueva y validar GPS.
7. Confirmar que aparece en Servicios activos.
8. Abrir un servicio finalizado y verificar Historial.
