# FIXIS — QA Matrix

Ultima actualizacion: 2026-09-26

## Estados

- PASS
- FAIL
- PENDING
- BLOCKED

## Release actual

| Area | Estado | Evidencia |
|---|---|---|
| Flutter Analyze | PENDING | CI anterior paso en 37a8e50; ejecutar de nuevo en Mac tras incorporar calificaciones y fidelizacion de la migracion 033 |
| Flutter Test | BLOCKED | No existen tests automatizados suficientes |
| Android Debug Build | PASS | CI en 37a8e50 con .env de prueba; usuario reporta APK actualizado funcionando el 2026-09-25 |
| Iconos FIXIS Android/iOS/web y login | PENDING | Logo y llave incorporados al proyecto; ejecutar `flutter pub get` y `dart run flutter_launcher_icons`, comprobar visualmente en dispositivos y reconstruir instalaciones | 
| Android Release Bundle | PENDING | Configuracion de firma preparada en ae7aef3; requiere clave privada, .env real y compilacion firmada |
| Android Physical QA | PENDING | Acceso y radar reportados en dos Android, uno en Santo Domingo y otro en Quito, a distancia superior a 25 km segun usuario; una misma cuenta ingreso despues desde otro dispositivo y se completo el servicio hasta pago; faltan calificacion, fidelizacion y rutas adicionales |
| iOS Build | PASS | Compilacion e instalacion mediante flutter run en iPhone 15 |
| iOS Install/Launch Smoke | PASS | 2026-09-25: usuario confirma que build release abre con normalidad desde icono en iPhone 15 Pro sin depurador; informe del fallo al reabrir muestra build debug |
| iOS Physical QA | PENDING | Acceso en tres iPhone, flujo hasta pago y arranque release sin depurador reportados; faltan calificacion bilateral, fidelizacion y rutas adicionales por rol |
| iOS Login OTP | PENDING | Acceso a las cuentas probado en tres iPhone; no consta evidencia separada de envio/reenvio OTP, codigo ni persistencia de sesion para todos los roles |
| iOS Admin despues de autorizacion de pago | PASS | Administrador verifico el pago por transferencia bancaria del cliente tras completar el flujo en tres telefonos; liquidacion al profesional aun no transferida |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline (2026-09-16) | PASS | Conteos en cero al terminar el reset; no describe el estado actual de la base |
| Backend Revised Quote / Realtime preflight | PASS | 2026-09-25: siete indicadores true en bloque 1 de supabase/qa/FIXIS_PRODUCTION_READINESS_READONLY.sql, resultado proporcionado desde Supabase |
| Backend integridad transaccional de lectura | PASS | 2026-09-25: los cinco conteos del bloque 2 siguieron en cero tras registrar la transferencia; resultado proporcionado desde Supabase |
| Revised Quote Flow | PASS | Recorrido de cotizacion revisada hasta pago del cliente y verificacion administrativa probado en tres telefonos; otros casos de revision aun requieren prueba |
| Quote Revision Realtime | PENDING | Migracion 031 y suscripcion Flutter preparadas; verificar aplicacion real y latencia en dispositivos |
| Revision Notification FIXI | PENDING | Evento persistente e in-app preparado; falta QA fisico |
| Cross-device Safe Areas | PENDING | 23 pantallas auditadas; validar Redmi Note 12, iPhone 15 y iPhone 15 Pro |
| Radar a distancia | PASS | Usuario reporta deteccion y uso del radar entre Android en Quito y Santo Domingo a distancia superior a 25 km; no equivale a verificar precision GPS ni prevencion de ubicacion simulada |
| Acceso y servicio entre dispositivos | PASS | Tres iPhone y dos Android usados en pruebas; cuenta usada en Quito pudo ingresar en otro dispositivo en Santo Domingo y recorrer servicio hasta pago del cliente |
| Ratings/Loyalty backend preflight | PASS | Usuario aplico migracion 033 con Success; siete indicadores true, anomalias y duplicados en cero antes de crear calificaciones; repetir tras QA fisico |
| Calificacion cliente a FIXI | PENDING | Migracion 033 aplicada; backend y permisos validados por usuario (7 indicadores true); falta compilar e ingresar como cliente para calificar un servicio con pago confirmado |
| Calificacion FIXI a cliente | PENDING | Migracion 033 aplicada; historial profesional y pantalla preparados; falta QA bilateral fisico, segundo intento y autorizacion de terceros |
| Fidelizacion cliente | PENDING | Migracion 033 aplicada; RPC verificada; perfil muestra servicios pagados, categorias y reconocimientos a 3 y 10 pagos; falta compilar y validar en cuenta real; sin descuentos ni canjes |
| Nivel FIXIS profesional | PENDING | Pantalla lee expert_gamification y suma servicios confirmados; promedio de calificaciones recibidas preparado en perfil; faltan validar progreso y calificaciones en dispositivos; beneficios o rangos adicionales sin definir |
| Finance Regression | PENDING | Dos pagos conciliados; corte semanal en processing sin debito; billetera profesional confirma saldo disponible cero, ganancias reservadas y retirado cero; migracion 032 y build iOS release verificados por usuario: referencia requerida, notas opcionales; textos de billetera corregidos en codigo, falta compilar nueva version, transferencia real y cierre paid |
| Security Regression | PENDING | RLS activo en ocho tablas y permisos RPC correctos; simulaciones SQL de customer, professional y admin pasan; accesos reales reportados en cinco telefonos, incluida misma cuenta en otro dispositivo; falta comprobar aislamiento entre cuentas con sesiones reales |
| Login / Signup Android actualizado | PENDING | Acceso con cuentas reales reportado en dos Android y reutilizacion de una cuenta en otro dispositivo; faltan pruebas separadas de alta, OTP por rol, correo ya usado y reenvio |

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
o BLOCKED. Calificacion bilateral y fidelizacion basada en actividad pagada estan
implementadas en la rama; migracion 033 aplicada y preflight aprobado, pendientes de compilacion y QA fisico.
No se habilitan descuentos, puntos monetarios ni canjes sin reglas comerciales.
