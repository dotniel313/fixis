# FIXIS PRO v1.2.0 — Quotes

Fecha: 2026-09-08

## Objetivo
Incorporar el primer flujo comercial estructurado de FIXIS PRO: aceptar una oportunidad, preparar una cotización separando mano de obra/materiales/otros y enviarla al cliente sin generar todavía comisiones ni pagos.

## Backend
- Nueva tabla `quotes`.
- `jobs.accepted_quote_id` preparado para la aceptación futura del cliente.
- `accept_job()` cambia de `pending -> in_progress` a `pending -> accepted`.
- Nueva RPC `create_quote()`.
- Nueva RPC `submit_quote()`.
- `total_amount` se calcula en PostgreSQL como columna generada.
- Escritura directa en `quotes` bloqueada para Flutter.
- Cotización enviada queda bloqueada para edición en v1.2.0.

## Flutter
- Nuevo flujo de cotización en `JobDetailScreen`.
- Nueva pantalla `CreateQuoteScreen`.
- Nueva pantalla `QuoteSummaryScreen`.
- Nuevo stream `myActiveJobsStreamProvider`.
- Dashboard muestra `Mis servicios activos` aunque el radar esté desconectado.
- Se elimina de `JobSuccessScreen` la ganancia ficticia de USD 34.
- Flujo de evidencia se conserva únicamente para trabajos legacy `in_progress`.

## Estado comercial
Esta versión NO implementa:
- aceptación de cotización por cliente;
- comisión FIXIS;
- pagos;
- ledger;
- liquidaciones.

La cotización enviada debe quedar en `quote_submitted` esperando la futura decisión del cliente.
