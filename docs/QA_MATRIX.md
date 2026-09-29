# FIXIS — QA Matrix

Ultima actualizacion: 2026-09-28

## Estados

- PASS
- FAIL
- PENDING
- BLOCKED

## Release actual

| Area | Estado | Evidencia |
|---|---|---|
| Flutter Analyze | PASS | CI 36509341949, reintento del job, aprobo flutter analyze en la rama actual. |
| Flutter Test | PENDING | CI 36509341949, reintento del job, aprobo 9 pruebas: limites de fidelizacion, pertenencia de decision de acceso a la sesion, intencion OTP de ingreso/alta y referencia bancaria obligatoria con HTTP simulado. Faltan pruebas de integracion contra backend de ensayo. |
| Android Debug Build | PASS | CI 36509341949, reintento del job, genero iconos, analizo, ejecuto 9 pruebas y compilo APK debug con configuracion simulada. El primer intento fallo por HTTP 504 al descargar Gradle; el reintento concluyo bien. APK release firmado y QA fisico registrados por separado. |
| Icono FIXIS iOS y logo login | PASS | 2026-09-27: captura de Biblioteca de apps en iPhone muestra icono azul con llave blanca FIXIS instalado; captura anterior confirmo el mismo simbolo en login. Se verificaron assets iOS versionados, evitando que git pull restablezca el icono Flutter |
| Icono FIXIS Android | PASS | 2026-09-27: captura de dispositivo Android confirma llave blanca sobre fondo azul en el launcher. El nombre visible FIXIS se ajusto despues de esta captura; comprobar al instalar la siguiente compilacion |
| Favicon del sitio publico FIXIS | PASS | 2026-09-27: captura de Safari en fixis.geotactics.com.ec muestra favicon de llave blanca sobre fondo azul y titulo FIXIS |
| Identidad de Flutter web | PENDING | favicon e iconos PNG versionados; titulo, nombre de instalacion y descripcion corregidos a FIXIS en web/index.html y web/manifest.json. Falta compilar y comprobar esta app web por separado del sitio publico |
| Android Release Bundle | PASS | 2026-09-28: usuario genero clave de subida JKS privada y compilo en su Mac app-release.aab firmado (49,1 MB); SHA-256 0d448b1cb4a9700997d2cf6ffc5c6f28b98964999bbac43d48878ff917357d3c. Firma AAB verificada independientemente con jarsigner (`jar verified`); avisos de certificado autofirmado/cadena no confiable y falta de sello de tiempo documentados. Pendiente registro en Play Console y distribucion; no equivale a QA fisico ni financiero aprobado |
| Google Play target SDK 36 | PASS | 2026-09-28: usuario inspecciono el APK release firmado en su Mac con apkanalyzer y obtuvo target SDK 36. El proyecto usa AGP 8.9.1; API y compatibilidad nativa de 16 KB se validan por separado. |
| Google Play compatibilidad 16 KB | PENDING | El APK/AAB incluye bibliotecas nativas por Flutter y dependencias; falta comprobar alineacion ZIP y ELF de las bibliotecas del artefacto release antes de cargarlo en Play Console. |
| Cambio de cuenta admin a cliente en Android release | PASS | 2026-09-28: tras corregir AuthGate y actualizar APK release firmado en Redmi, usuario confirma acceso rapido y directo al perfil de Jhony Torres, sin paso visible por panel admin. CI 36486339815 aprobo analisis, pruebas y APK debug; otros cambios de rol quedan para QA complementaria |
| Cambio de cuenta cliente a profesional en Android release | PASS | 2026-09-28: tras verificar OTP en Redmi Note 12, usuario confirma acceso rapido al rol profesional con su propio progreso; no observo datos ni pantalla de la cuenta cliente previa. |
| Alta de cliente nuevo en Android release | PASS | 2026-09-28: el usuario confirma que la cuenta de cliente de prueba se creo desde el mismo Redmi y APK release, permitio ingreso y muestra solo su perfil sin historial previo. |
| Android Release Install/Launch Smoke | PASS | 2026-09-28: usuario instala APK release firmado en Redmi desde archivo local; abre, envia OTP, entra como administrador y visualiza liquidacion con su accion disponible. No se ejecuto pago de liquidacion |
| Identidad e historial de cliente entre iPhone y Redmi | PASS | 2026-09-28: captura de usuarios de Supabase confirma dos cuentas distintas con nombres visibles Jhony y Jhonny Torres y correos diferentes; la captura anterior de Mi perfil en iPhone identifica a Jhonny como titular del servicio confirmado y la reseña 3/5. La cuenta Jhony abierta en Redmi no tiene servicios ni reseñas, como corresponde a su propia identidad. No se publican correos en esta matriz. |
| Android Physical QA | PENDING | Acceso y radar probados entre Android en Santo Domingo y Quito; servicio hasta pago y calificacion cliente a FIXI verificados. Fidelizacion basica y reseña recibida del cliente probadas en Android. 2026-09-28: APK release firmado instalado en Redmi; OTP y acceso administrador verificados sin ejecutar liquidacion. Cambio a cliente y luego a profesional rapido y con datos del rol correcto, sin paso visible por la cuenta anterior. Usuario confirma espacio inferior suficiente en Billetera y Actividad. Quedan otras pantallas y estados de teclado para QA complementaria. |
| iOS Build | PASS | 2026-09-26: usuario actualizo la rama e instalo en iPhone 15 Pro; captura de la compilacion actual muestra el mensaje de pago corregido en el detalle de su servicio |
| iOS Install/Launch Smoke | PASS | 2026-09-25: usuario confirma que build release abre con normalidad desde icono en iPhone 15 Pro sin depurador; informe del fallo al reabrir muestra build debug |
| iOS Physical QA | PENDING | Acceso en tres iPhone, flujo hasta pago y arranque release sin depurador reportados; calificacion FIXI a cliente probada en iPhone; faltan fidelizacion y rutas adicionales por rol |
| iOS Login OTP | PENDING | 2026-09-27: usuario confirma en iPhone 15 que un cliente de pruebas entra con codigo y conserva la sesion tras cerrar y reabrir la app. Falta reenvio y validacion separada de los otros roles |
| iOS Admin despues de autorizacion de pago | PASS | Administrador verifico el pago por transferencia bancaria del cliente tras completar el flujo en tres telefonos; liquidacion al profesional aun no transferida |
| Supabase Transactional Reset | PASS | docs/QA_TRANSACTIONAL_RESET_v1.10.8.7.md |
| Backup Transactional | PASS | fixis_backup_reset_20260916 |
| Clean Database Baseline (2026-09-16) | PASS | Conteos en cero al terminar el reset; no describe el estado actual de la base |
| Backend Revised Quote / Realtime preflight | PASS | 2026-09-25: siete indicadores true en bloque 1 de supabase/qa/FIXIS_PRODUCTION_READINESS_READONLY.sql, resultado proporcionado desde Supabase |
| Backend integridad transaccional de lectura | PASS | 2026-09-25: los cinco conteos del bloque 2 siguieron en cero tras registrar la transferencia; resultado proporcionado desde Supabase |
| Revised Quote Flow | PASS | Recorrido de cotizacion revisada hasta pago del cliente y verificacion administrativa probado en tres telefonos; 2026-09-27: usuario confirma en dispositivos fisicos envio de cotizacion inicial y solicitud posterior de ampliacion. Otros casos de rechazo/cancelacion quedan para QA complementaria |
| Quote Revision Realtime | PASS | 2026-09-27: usuario confirma en dispositivos fisicos que envio de cotizacion, solicitud de ampliacion y aceptacion se reflejaron de inmediato en el otro telefono sin salir ni volver a entrar. Suscripcion jobs y migracion 031 activas. La notificacion persistente FIXI se valida por separado |
| Revision Notification FIXI | PASS | 2026-09-27: usuario confirma que al aceptar la ampliacion en dispositivos fisicos llega al FIXI la notificacion Nuevo alcance aceptado; backend crea evento persistente y la app lo presenta. El stream versionado filtra user_id, respaldado por RLS |
| Cross-device Safe Areas | PENDING | 23 pantallas auditadas; detalle de servicio confirmado completo en Redmi Note 12 e iPhone 15 Pro, con boton de opinion separado de la barra inferior. 2026-09-28: Billetera y Actividad del profesional en APK release del Redmi tienen espacio inferior suficiente segun prueba fisica del usuario. Faltan otras pantallas y estados con teclado en Redmi e iPhone 15. |
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
| Reconocimientos a 3 y 10 pagos | PENDING | CI 36369387263 valida de forma aislada el cálculo de limites 3 y 10, sin crear pagos ficticios; falta comprobar RPC y UI con cuentas reales al alcanzar ambos umbrales |
| Nivel FIXIS profesional | PASS | 2026-09-26: captura iPhone muestra rango Inicial, 2 servicios confirmados, progreso 2/5 y 3 para meta, coherentes con dos trabajos del profesional; beneficios futuros siguen sin reglas definidas |
| Finance Regression | PASS | Alcance financiero probado en EC/USD: cliente transfiere a la cuenta asignada y adjunta comprobante; administrador verifica la recepcion antes de confirmar el pago. Dos pagos de prueba quedaron paid y conciliados, con una ganancia y una comision por pago; corte semanal reservado en processing sin debito de salida. La transferencia posterior al FIXI se gestiona manualmente y permanece pendiente, sin marcarla pagada. Migracion 032 y prueba CI de referencia obligatoria protegen ese cierre posterior; no se ejecuto transferencia real al FIXI. |
| Security Regression | PASS | RLS activo en ocho tablas y permisos RPC correctos; simulaciones SQL confirmadas: cliente ve su pago, no ve pagos ajenos ni liquidaciones; profesional ve sus ganancias y liquidacion, no la comision FIXIS; administrador ve pagos y liquidaciones. Aislamiento de identidad/calificaciones y migracion 035 validados. 2026-09-26: Jhony Torres en iPhone 15 Pro no ve servicios de Maria Jose, y capturas confirman su perfil, reseña 3/5, servicio propio y pago confirmado. Version actual instalada en iPhone 15 Pro; QA de compilacion Android sigue pendiente en fila Android Physical QA |
| Preparacion operativa de cobros y transferencias | BLOCKED | 2026-09-28: primer mercado Ecuador / USD; existe 1 cuenta receptora activa EC/USD, pero el usuario confirma que no es la cuenta operativa definitiva para cobros reales. No aceptar transferencias reales hacia la cuenta de pruebas. Antes de habilitar el cobro real, configurar y comprobar la cuenta designada visible al cliente y el procedimiento de cotejo del comprobante con el abono bancario. El desembolso posterior al FIXI exige transferencia efectiva y referencia antes de marcar liquidacion pagada. |
| Login / Signup Android actualizado | PASS | 2026-09-27: reenvio OTP tras 60 segundos e ingreso al perfil correcto confirmados. 2026-09-28: alta de cliente nuevo realizada con APK release en Redmi; OTP permite entrar a perfil propio. Intento con correo ya vinculado a otro rol no cambia el rol; usuario reviso tabla profiles en Supabase y confirma que no se creo perfil duplicado en el caso probado. Evidencia de inspeccion visual; no representa auditoria global de unicidad. |

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
Finance Regression, Security Regression, Preparacion operativa de cobros y
transferencias, Google Play target SDK 36, Google Play compatibilidad 16 KB o QA fisico
permanezcan en PENDING o BLOCKED. Calificacion bilateral y fidelizacion basada en actividad pagada estan
implementadas en la rama; migraciones 033/034 aplicadas y preflight aprobado; CI compilo APK debug, instalacion realizada y calificacion bilateral probada en iPhone/Android; otras rutas fisicas pendientes.
No se habilitan descuentos, puntos monetarios ni canjes sin reglas comerciales.
