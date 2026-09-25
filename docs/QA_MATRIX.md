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
| Flutter Analyze | PASS | CI en 37a8e50 con nueva configuracion de firma |
| Flutter Test | BLOCKED | No existen tests automatizados suficientes |
| Android Debug Build | PASS | CI en 37a8e50 con .env de prueba; usuario reporta APK actualizado funcionando el 2026-09-25 |
| Android Release Bundle | PENDING | Configuracion de firma preparada en ae7aef3; requiere clave privada, .env real y compilacion firmada |
| Android Physical QA | PENDING | Usuario reporta que funciona el 2026-09-25; faltan evidencias por rol y recorrido funcional completo |
| iOS Build | PASS | Compilacion e instalacion mediante flutter run en iPhone 15 |
| iOS Install/Launch Smoke | PASS | 2026-09-25: usuario confirma que build release abre con normalidad desde icono en iPhone 15 Pro sin depurador; informe del fallo al reabrir muestra build debug |
| iOS Physical QA | PENDING | Flujo de pago en tres telefonos y arranque release sin depurador validados; faltan otras rutas por rol y sesion/reingreso |
| iOS Login OTP | PENDING | 2026-09-25: acceso del administrador funciona en iPhone 15 Pro release; faltan comprobar por separado envio/codigo OTP y retencion de sesion en todos los roles |
| iOS Admin despues de autorizacion de pago | PASS | 2026-09-25: usuario confirma que el administrador registro la transferencia tras completar el flujo en los tres telefonos de prueba |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline (2026-09-16) | PASS | Conteos en cero al terminar el reset; no describe el estado actual de la base |
| Backend Revised Quote / Realtime preflight | PASS | 2026-09-25: siete indicadores true en bloque 1 de supabase/qa/FIXIS_PRODUCTION_READINESS_READONLY.sql, resultado proporcionado desde Supabase |
| Backend integridad transaccional de lectura | PASS | 2026-09-25: los cinco conteos del bloque 2 siguieron en cero tras registrar la transferencia; resultado proporcionado desde Supabase |
| Revised Quote Flow | PASS | 2026-09-25: usuario confirma recorrido completo hasta el pago y registro de transferencia por administrador en tres telefonos; otros casos de revision aun requieren prueba |
| Quote Revision Realtime | PENDING | Migracion 031 y suscripcion Flutter preparadas; verificar aplicacion real y latencia en dispositivos |
| Revision Notification FIXI | PENDING | Evento persistente e in-app preparado; falta QA fisico |
| Cross-device Safe Areas | PENDING | 23 pantallas auditadas; validar Redmi Note 12, iPhone 15 y iPhone 15 Pro |
| Finance Regression | PENDING | Dos pagos conciliados; corte semanal en processing sin debito; migracion 032 y build iOS release verificados por usuario: referencia requerida, notas opcionales; falta transferencia real y cierre paid |
| Security Regression | PENDING | RLS activo en ocho tablas y permisos RPC correctos; simulaciones SQL de customer y professional pasan: aislamiento de pagos, liquidaciones y comision FIXIS; faltan admin y pruebas con sesiones reales |
| Login / Signup Android actualizado | PENDING | Funcionamiento general reportado el 2026-09-25; falta registrar resultados separados: OTP cliente/FIXI/admin, correo existente de otro rol y reenvio |

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
