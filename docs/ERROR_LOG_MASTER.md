# FIXIS PRO — Bitácora Maestra de Errores y Deuda

| ID | Área | Descripción | Estado |
|---|---|---|---|
| ERR-001 | DB | FK duplicada durante migración inicial | Cerrado |
| SEC-001 | Finanzas | Cliente podía fabricar earnings | Cerrado |
| SEC-002 | Jobs | UPDATE directo sobre jobs | Cerrado |
| SEC-003 | Jobs | Pending jobs expuestos públicamente | Cerrado |
| SEC-004 | Gamificación | Escritura directa desde cliente | Cerrado |
| SEC-005 | DB | Grants excesivos | Cerrado |
| ARC-001 | Auth | Roles ausentes | Cerrado |
| ARC-002 | Auth | authenticated confundido con autorizado | Cerrado |
| PERF-001 | Auth | Latencia percibida de OTP | Pendiente |
| PERF-002 | Auth | Demora AuthGate/dashboard | Mejorado |
| FIN-002 | Finanzas | Earning hardcodeado $34 | Cerrado |
| GAM-001 | Gamificación | Backend fallback Platino/50 | Cerrado backend |
| LEG-001 | Backend | handle_new_user huérfana | Cerrado |
| LEG-002 | Backend | approve_professional legacy | Bloqueada / pendiente retiro |
| AUTH-003 | Auth | Onboarding profesional/customer inconsistente | Cerrado |
| DB-001 | Jobs | quote_submitted faltaba en CHECK | Cerrado |
| APP-001 | Flutter | complete_job_v1 seguía en app | Cerrado |
| UI-001 | Flutter | Mensaje “esperando confirmación” duplicado | Cerrado |
| DB-002 | Jobs | work_completed faltaba en state machine | Cerrado |
| DB-003 | Jobs | customer_approved faltaba en state machine | Cerrado |
| FIN-005 | Finanzas | Wallet simple sin ledger | Cerrado |
| FIN-006 | Finanzas | Falta de idempotencia | Cerrado |
| FIN-007 | Finanzas | Terminar trabajo generaba dinero demasiado pronto | Cerrado |
| GAM-002 | Flutter | Fallback visual Platino/50 aún presente | Abierto |
| DB-005 | DB | FK duplicada assigned_pro_id | Cerrado |
| ARC-003 | Jobs | client_id ausente | Cerrado |
| SEC-011 | RLS | Cliente futuro podía ver pending | Cerrado |
| SEC-012 | Quotes | Cliente sin lectura segura de quotes | Cerrado |
| SEC-013 | Approval | Aprobación dependía de trusted/admin | Cerrado |
| SEC-014 | Ownership | Sin validación de dueño cliente | Cerrado |
| GEO-001 | Geo | create_job producía coordenadas NULL | Cerrado |
| GEO-002 | Geo | Matching sin filtro seguro por radio/categoría | Cerrado |
| LIVE-001 | Geo | Live tracking solo foreground | Abierto conocido |
| BUILD-001 | Flutter | Bloque if fuera de método en v1.8.5 | Cerrado |
| UI-002 | Notifications | Pantalla contiene notificaciones ficticias | Abierto |
| LEG-004 | Flutter | JobSuccessScreen obsoleta | Abierto |
| LEG-005 | Jobs | completed legacy aún visible | Abierto controlado |
| ARC-004 | Flutter | Acceso Supabase directo desde screens | Abierto |
| ARC-005 | Flutter | Uso extensivo de Map<String,dynamic> | Abierto |
| ARC-006 | Flutter | Navegación MaterialPageRoute dispersa | Abierto |
| OFF-001 | Offline | Drift no refleja state machine/arquitectura actual | Abierto |
| TEST-001 | QA | Sin tests automatizados | Abierto crítico |
| DOC-001 | Docs | Changelogs/checklists dispersos | Abierto |
| AUD-001 | Release | Migraciones locales incompletas vs Supabase | Abierto crítico |
| AUD-002 | Release | Snapshot auditado sin pubspec/analysis_options | Abierto alto |
