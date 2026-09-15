# FIXIS PRO v1.10.8.0 — QA Hardening Base

Cambios seguros aplicados sin tocar Supabase:
- permiso INTERNET en Android main/release;
- corrección de comparación `statusCode` 504;
- hardening responsive de cotización en cliente;
- hardening de fila de importes del resumen;
- versión Flutter `1.10.8+10800`;
- matriz QA consolidada.

No se modificó:
- schema Supabase;
- RLS;
- RPCs;
- finanzas;
- autenticación;
- flujo de estados.

Próximo paso: ejecutar `flutter analyze`/build en el Mac del usuario y auditar Supabase real antes de implementar Referencia, fotos, agenda, cotización revisada, SLA, llegada geovalidada y Legal Onboarding.
