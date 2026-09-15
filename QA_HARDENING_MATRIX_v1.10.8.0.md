# FIXIS PRO v1.10.8.0 — QA Hardening Base

Fecha: 2026-09-14
Base auditada: fuente entregada por el usuario (lib/android/test + pubspec)
Objetivo: congelar base y cerrar bloqueantes antes de v2.0 RC1.

## Hallazgos ya corregidos en esta base

| ID | Área | Hallazgo | Estado |
|---|---|---|---|
| QA-ANDROID-001 | Android | `INTERNET` no estaba declarado en `src/main/AndroidManifest.xml`, solo debug/profile. | FIXED / DEVICE TEST |
| QA-AUTH-002 | Auth | `AuthException.statusCode` se comparaba con entero `504`; incompatible con la API actual. | FIXED / ANALYZE PENDING |
| QA-UI-001 | Cotización cliente | Encabezado `Propuesta del FIXI + total` podía desbordar en pantallas pequeñas/escalado de fuente. | FIXED / DEVICE TEST |
| QA-UI-002 | Resumen cotización | Fila de importe podía desbordar con valores/text scaling. | FIXED / DEVICE TEST |
| QA-VERSION-001 | Release | `pubspec` seguía en `1.0.0+1`. | FIXED: `1.10.8+10800` |

## Bloqueantes funcionales preproducción

| ID | Prioridad | Requisito | Estado | Dependencia |
|---|---:|---|---|---|
| QA-LOC-001 | Alta | Campo `Referencia` de domicilio, persistente y visible para Fixi. | OPEN | Validar schema real Supabase |
| QA-MEDIA-001 | Alta | Cliente puede adjuntar hasta 3 fotos iniciales del problema. | OPEN | Validar storage/RLS/schema |
| QA-SCHED-001 | Crítica | Propuesta/confirmación de día y hora de visita. | OPEN | Validar schema/RPC |
| QA-QUOTE-REV-001 | Crítica | Cotización revisada por cambio de alcance con nueva aceptación expresa del cliente y trazabilidad de versiones. | OPEN | Diseño DB/RPC/finanzas |
| QA-SLA-001 | Crítica | Si Fixi no contacta/avanza en plazo definido, cliente puede reportar, cancelar/republicar/reasignar con trazabilidad. | OPEN | Definir SLA + backend |
| QA-GEO-001 | Crítica | `mark_arrived` debe validar proximidad real al domicilio en backend, no solo botón Flutter. | OPEN | Auditar RPC `mark_arrived` real |
| LEGAL-001 | Crítica | Legal Onboarding obligatorio/versionado antes de usar la app. | OPEN | Schema + textos jurídicos |
| LEGAL-002 | Crítica | Términos Cliente y Fixi separados; aceptación auditable. | OPEN | Revisión jurídica |
| LEGAL-003 | Crítica | Política privacidad/LOPDP y consentimiento separado cuando aplique. | OPEN | Revisión jurídica |
| LEGAL-004 | Alta | Política ubicación/FIXIS Live y uso de geolocalización. | OPEN | Revisión jurídica |
| LEGAL-005 | Alta | Propiedad intelectual/licencia a favor de Geotactics S.A. + terceros/proveedores. | OPEN | Revisión jurídica/titularidad |
| LEGAL-006 | Alta | Disclaimer de intermediario tecnológico sin excluir responsabilidades legales irrenunciables. | OPEN | Revisión jurídica |
| QA-AUTH-001 | Alta | Evaluar OTP por teléfono para usuarios sin uso habitual de correo; WhatsApp solo tras evaluar proveedor/costos. | OPEN / NO CAMBIAR AÚN | Arquitectura Auth |
| QA-MAP-001 | Media | Mejorar mapa/navegación visual, ETA, marcador y bottom sheet. | OPEN | Después de bloqueantes |

## Hallazgos de release todavía abiertos

| ID | Área | Hallazgo | Estado |
|---|---|---|---|
| QA-REL-001 | Firma | `release` continúa usando `signingConfigs.debug`. No apto para Play Console. | OPEN / BLOQUEANTE AAB |
| QA-REL-002 | Secrets | `pubspec.yaml` carga `.env`; el ZIP QA no incluye secretos, correctamente. Debe existir localmente para build. | VERIFY |
| QA-REL-003 | Analyzer | Este entorno de auditoría no dispone del binario Flutter; ejecutar `flutter analyze` en Mac del proyecto. | PENDING |
| QA-REL-004 | Tests | `test/` recibido sin tests visibles en el ZIP. Crear smoke tests mínimos antes de RC. | OPEN |

## Flujo objetivo de pruebas físicas

Cliente crea solicitud → referencia/fotos → matching → Fixi acepta → agenda/contacto → cotización → Cliente aprueba → Fixi en ruta → FIXIS Live → llegada validada por GPS → inicio → evidencia antes/después → posible cotización revisada → finalización → aprobación del cliente → snapshot/ledger/wallet/settlement.

## Regla de freeze

Durante v1.10.8 solo se incorporan correcciones QA, seguridad, legal-onboarding y funciones operativas consideradas bloqueantes. Rating bilateral, tributación completa y mejoras cosméticas no bloqueantes quedan registradas para la siguiente fase salvo dependencia directa del RC.
