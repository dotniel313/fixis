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
| Flutter Analyze | PASS | CI 36254445169 aprobo flutter analyze tras incorporar calificaciones, fidelizacion, iconos y la pantalla de nombre/foto |
| Flutter Test | BLOCKED | No existen tests automatizados suficientes |
| Android Debug Build | PASS | CI 36254445169 genero iconos, analizo y compilo APK debug con .env de prueba; compilacion release y QA fisico siguen pendientes |
| Iconos FIXIS Android/iOS/web y login | PENDING | 2026-09-26: se detecto que el icono iOS versionado seguia siendo el predeterminado de Flutter; se incorporaron los iconos FIXIS generados para iOS, Android y web a la rama. Usuario reporta actualizacion en iPhone 15; captura 2026-09-26 confirma logo azul FIXIS dentro del login y layout sin cortes. El icono de la pantalla de inicio del iPhone requiere captura/verificacion aparte antes de marcar PASS | 
| Android Release Bundle | PENDING | Configuracion de firma preparada en ae7aef3; requiere clave privada, .env real y compilacion firmada |
| Android Physical QA | PENDING | Acceso y radar probados entre Android en Santo Domingo y Quito; servicio hasta pago y calificacion cliente a FIXI verificados. Fidelizacion basica y reseña recibida del cliente probadas en Android. 2026-09-26: version actual instalada en Redmi Note 12; captura de detalle de servicio confirmado muestra nuevo texto de pago, boton de opinion completo y espacio inferior suficiente sobre la barra de navegacion. Otras rutas y compilacion release firmada siguen pendientes |
| iOS Build | PASS | 2026-09-26: usuario actualizo la rama e instalo en iPhone 15 Pro; captura de la compilacion actual muestra el mensaje de pago corregido en el detalle de su servicio |
| iOS Install/Launch Smoke | PASS | 2026-09-25: usuario confirma que build release abre con normalidad desde icono en iPhone 15 Pro sin depurador; informe del fallo al reabrir muestra build debug |
| iOS Physical QA | PENDING | Acceso en tres iPhone, flujo hasta pago y arranque release sin depurador reportados; calificacion FIXI a cliente probada en iPhone; faltan fidelizacion y rutas adicionales por rol |
| iOS Login OTP | PENDING | Acceso a las cuentas probado en tres iPhone; no consta evidencia separada de envio/reenvio OTP, codigo ni persistencia de sesion para todos los roles |
| iOS Admin despues de autorizacion de pago | PASS | Administrador verifico el pago por transferencia bancaria del cliente tras completar el flujo en tres telefonos; liquidacion al profesional aun no transferida |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline (2026-09-16) | PASS | Conteos en cero al terminar el reset; no describe el estado actual de la base |
| Backend Revised Quote / Realtime preflight | PASS | 2026-09-25: siete indicadores true en bloque 1 de supabase/qa/FIXIS_PRODUCTION_READINESS_READONLY.sql, resultado proporcionado desde Supabase |
| Backend integridad transaccional de lectura | PASS | 2026-09-25: los cinco conteos del bloque 2 siguieron en cero tras registrar la transferencia; resultado proporcionado desde Supabase |
| Revised Quote Flow | PASS | Recorrido de cotizacion revisada hasta pago del cliente y verificacion administrativa probado en tres telefonos; 2026-09-27: usuario confirma en dispositivos fisicos envio de cotizacion inicial y solicitud posterior de ampliacion. Otros casos de rechazo/cancelacion quedan para QA complementaria |
| Quote Revision Realtime | PASS | 2026-09-27: usuario confirma en dispositivos fisicos que envio de cotizacion, solicitud de ampliacion y aceptacion se reflejaron de inmediato en el otro telefono sin salir ni volver a entrar. Suscripcion jobs y migracion 031 activas. La notificacion persistente FIXI se valida por separado |
| Revision Notification FIXI | PASS | 2026-09-27: usuario confirma que al aceptar la ampliacion en dispositivos fisicos llega al FIXI la notificacion Nuevo alcance aceptado; backend crea evento persistente y la app lo presenta. El stream versionado filtra user_id, respaldado por RLS |
| Cross-device Safe Areas | PENDING | 23 pantallas auditadas; el detalle de servicio confirmado se ve completo en Redmi Note 12 y iPhone 15 Pro, con boton de opinion separado de la barra inferior. Falta validar las demas pantallas y estados con teclado en Redmi e iPhone 15 |
| Radar a distancia | PASS | Usuario reporta deteccion y uso del radar entre Android en Quito y Santo Domingo a distancia superior a 25 km; no equivale a verificar precision GPS ni prevencion de ubicacion simulada |
| Acceso y servicio entre dispositivos | PASS | Tres iPhone y dos Android usados en pruebas; cuenta usada en Quito pudo ingresar en otro dispositivo en Santo Domingo y recorrer servicio hasta pago del cliente |
| Ratings/Loyalty backend preflight | PASS | Usuario aplico migraciones 033 y 034; 2026-09-26: siete indicadores true, anomalias y duplicados en cero, y tres indicadores true para RPC de identidad; repetir tras QA fisico |
| Boton de calificacion y reputacion de cliente | PASS | 2026-09-26: iPhone confirma llave naranja/gris y boton Ver mi calificacion; captura Android del cliente muestra 5,00 / 5 y 1 opinion recibida junto a su identidad | 
| Calificacion cliente a FIXI | PASS | 2026-09-26: Android muestra a Daniel Orellana con foto y calificacion de 5 llaves guardada; SQL confirma una calificacion del cliente en el servicio 9a051626 |
| Estado de calificacion en actividad profesional | PASS | 2026-09-26: tras calificar los dos servicios, captura iPhone muestra ambas llaves naranjas y Cliente calificado en ambas filas; llave gris corresponde solo a trabajo pendiente de calificacion | 
| Calificacion FIXI a cliente | PASS | 2026-09-26: iPhone muestra 5 llaves guardadas para Maria Jama y silueta esperada sin foto; SQL confirma una calificacion del FIXI en el mismo servicio 9a051626; reingreso sigue como prueba complementaria |
| Aislamiento de calificaciones entre cuentas | PASS | 2026-09-26: consulta con tercero simulado devolvio tres true y usuario confirma prueba fisica con cuentas distintas: Jhony Torres no ve la calificacion de Maria Jose desde su cuenta |
| Reseñas recibidas y textos de calificacion | PASS | 2026-09-26: iPhone FIXI confirma opinion recibida con identidad y comentario; Android cliente Maria Jose muestra 1 reseña recibida de Daniel Orellana con foto, fecha, titulo del servicio, 5 llaves naranjas y texto completo. Migracion 035: privilegios true/true/true, tercero simulado true/true; aislamiento entre cuentas comprobado por usuario. |
| Fidelizacion cliente | PASS | 2026-09-26: captura Android de Maria muestra 1 servicio pagado, 1 categoria y 2 servicios restantes para reconocimiento a 3; RPC aplicada, sin dinero, descuentos ni canjes | 
| Reconocimientos a 3 y 10 pagos | PENDING | Logica preparada y primer tramo probado con 1 pago; faltan cuentas reales con 3 y 10 pagos o verificacion aislada de umbrales |
| Nivel FIXIS profesional | PASS | 2026-09-26: captura iPhone muestra rango Inicial, 2 servicios confirmados, progreso 2/5 y 3 para meta, coherentes con dos trabajos del profesional; beneficios futuros siguen sin reglas definidas |
| Finance Regression | BLOCKED | Dos pagos de clientes conciliados: cada uno con una ganancia y una comision; corte semanal de 102,00 en processing, sin debito de liquidacion. Billetera profesional confirma ganancias reservadas y retirado cero. Migracion 032 y flujo administrativo iOS verificados: referencia requerida y notas opcionales. 2026-09-26: el usuario aclara que aun no hay cuenta bancaria operativa asociada durante las pruebas; no corresponde transferir ni marcar la liquidacion pagada. La verificacion financiera de pagos y reserva es PASS; el cierre real queda bloqueado hasta definir cuenta y operacion real. |
| Security Regression | PASS | RLS activo en ocho tablas y permisos RPC correctos; simulaciones SQL confirmadas: cliente ve su pago, no ve pagos ajenos ni liquidaciones; profesional ve sus ganancias y liquidacion, no la comision FIXIS; administrador ve pagos y liquidaciones. Aislamiento de identidad/calificaciones y migracion 035 validados. 2026-09-26: Jhony Torres en iPhone 15 Pro no ve servicios de Maria Jose, y capturas confirman su perfil, reseña 3/5, servicio propio y pago confirmado. Version actual instalada en iPhone 15 Pro; QA de compilacion Android sigue pendiente en fila Android Physical QA |
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
implementadas en la rama; migraciones 033/034 aplicadas y preflight aprobado; CI compilo APK debug, instalacion realizada y calificacion bilateral probada en iPhone/Android; otras rutas fisicas pendientes.
No se habilitan descuentos, puntos monetarios ni canjes sin reglas comerciales.
