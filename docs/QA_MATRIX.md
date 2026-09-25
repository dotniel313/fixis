# FIXIS — QA Matrix

Ultima actualizacion: 2026-09-25

## Estados

- PASS
- FAIL
- PENDING
- BLOCKED

## Release actual

| Area | Estado | Evidencia |
|---|---|---|
| Flutter Analyze | PASS | CI del flujo Android/Auth en 1098631; nueva configuracion de firma pendiente de CI |
| Flutter Test | BLOCKED | No existen tests automatizados suficientes |
| Android Debug Build | PASS | CI en 1098631 con .env de prueba; APK con entorno real pendiente |
| Android Release Bundle | PENDING | Configuracion de firma preparada en ae7aef3; requiere clave privada, .env real y compilacion firmada |
| Android Physical QA | PENDING | Requiere dispositivo |
| iOS Build | PASS | Compilacion e instalacion mediante flutter run en iPhone 15 |
| iOS Install/Launch Smoke | PASS | Runner inicio correctamente; pausa observada correspondia a breakpoint local de Xcode |
| iOS Physical QA | PENDING | Falta ejecutar el flujo funcional end-to-end |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline (2026-09-16) | PASS | Conteos en cero al terminar el reset; no describe el estado actual de la base |
| Revised Quote Flow | PENDING | E2E llego hasta aceptacion de revision; continuar tras hotfix |
| Quote Revision Realtime | PENDING | Migracion 031 y suscripcion Flutter preparadas; verificar aplicacion real y latencia en dispositivos |
| Revision Notification FIXI | PENDING | Evento persistente e in-app preparado; falta QA fisico |
| Cross-device Safe Areas | PENDING | 23 pantallas auditadas; validar Redmi Note 12, iPhone 15 y iPhone 15 Pro |
| Finance Regression | PENDING | quote -> snapshot -> payment -> ledger -> settlement |
| Security Regression | PENDING | Validar RLS y RPC despues del E2E |
| Login / Signup Android actualizado | PENDING | Probar OTP de cliente/FIXI/admin, cuenta nueva, correo existente de otro rol y reenvio en el APK con .env real |

## Criterios v1.10.8.6

- Preserva cotizacion original
- Revision solo en arrived
- Motivo obligatorio
- Cliente visualiza comparacion
- Rechazo conserva snapshot anterior
- Aceptacion crea snapshot vigente
- Solo un snapshot current
- Revision pendiente bloquea start_job
- Payment usa snapshot vigente
- Ledger usa snapshot vigente
- No duplica earning
- No duplica commission

## Regla de cierre

La version no puede pasar a release mientras Revised Quote Flow,
Finance Regression, Security Regression y QA fisico permanezcan en PENDING
o BLOCKED.
