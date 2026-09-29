# FIXIS - prueba cerrada de Google Play

Estado: preparacion. Fecha: 2026-09-29. Primer mercado de prueba: Ecuador / USD.

## Artefacto

- Paquete Android: `ec.com.geotactics.fixis_pro`.
- Version actual del repositorio: `1.10.8+10805`; confirmar el versionCode del AAB final. Cada nueva carga posterior debe incrementarlo.
- El AAB firmado anterior al rediseño de mapas no incluye los cambios del 29 de septiembre. Sincronizar la rama, ejecutar QA fisico y generar un AAB release nuevo con la misma clave de subida privada.
- CI 36517646319: analisis, pruebas y APK debug aprobados. La matriz `docs/QA_MATRIX.md` mantiene QA fisico pendiente.
- No subir la clave JKS, contrasenas ni `key.properties` a GitHub.

## Configuracion de la consola

1. Si FIXIS no esta creada en la cuenta correcta, crear la app como aplicacion gratuita, idioma principal espanol y nombre FIXIS. La creacion incluye declaraciones y terminos que debe revisar y aceptar el titular de la cuenta.
2. Completar la ficha de Play, politica de privacidad publica, instrucciones de acceso por OTP para el equipo de revision, clasificacion, publico objetivo y Seguridad de los datos con informacion comprobada del flujo real. No inferir respuestas de privacidad a partir del manifiesto solamente.
3. Ir a **Prueba y lanzamiento > Pruebas > Prueba cerrada**. Crear una lista de correos de Google de los testers; reunir 20 deja margen frente al minimo aplicable de 12 testers inscritos continuamente durante 14 dias para cuentas personales nuevas.
4. Elegir los paises del ensayo y canal de comentarios, cargar el AAB final firmado, revisar advertencias y enviar la version a revision/publicacion de prueba cerrada.
5. Cuando la version este publicada, compartir el enlace de participacion. Cada tester debe acceder con la cuenta de Google incluida en la lista y aceptar participar. Registrar la fecha y comprobar el contador de participantes en la consola; agregar un correo a la lista no equivale a inscribirse.
6. Recoger comentarios sobre registro OTP, radar, solicitud, cotizacion y revision, estados en tiempo real, mapa claro/nocturno, trayecto, pago simulado, calificacion bilateral, fidelizacion y SafeArea/teclado. Mantener un canal directo para errores con dispositivo, version y pasos.
7. Evaluar fallos y publicar actualizaciones del canal cerrado con versionCode superior. Solicitar acceso a produccion solo cuando la consola indique cumplida la condicion de prueba y los bloqueos operativos del QA esten cerrados.

## Alcance financiero de la prueba

La cuenta receptora EC/USD actual es de pruebas, no la cuenta operativa definitiva. No solicitar transferencias reales a testers. Para el recorrido del pago usar un escenario controlado por el equipo y no marcar como pagada una liquidacion sin transferencia efectiva y referencia.

## Trabajo tecnico pendiente del mapa

- Verificar visualmente dia/noche y movimiento del pin en Android e iPhone.
- El flujo actual comparte ubicacion durante `en_route` mientras la pantalla de detalle del profesional permanece abierta; al salir de ella se cancela la suscripcion GPS. No anunciar continuidad en segundo plano.
- Sustituir las teselas publicas de OpenStreetMap por un proveedor con condiciones de uso adecuadas para la escala comercial. Mantener la atribucion correspondiente.
- Una segunda categoria profesional requiere validacion y emparejamiento en backend antes de exponerla en el radar.

Fuentes oficiales:
- https://support.google.com/googleplay/android-developer/answer/9845334
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/9859455
