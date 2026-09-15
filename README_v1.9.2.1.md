# FIXIS PRO v1.9.2.1 — Admin Weekly Settlements UI

Base: v1.9.1.3.1 + Migration 022 aplicada.

Agrega una tercera pestaña al Admin:
- Por verificar
- Historial
- Liquidaciones

Funciones:
- Generar corte semanal
- Ver liquidaciones requested / processing
- Pasar requested → processing
- Marcar processing → paid
- Rechazar requested / processing
- Ver historial reciente paid / rejected / cancelled

El botón de corte usa el momento actual como cutoff y programa la liquidación
para el próximo viernes (o hoy si hoy es viernes).

No incluye SQL nuevo. Requiere Migration 022 ya aplicada.
