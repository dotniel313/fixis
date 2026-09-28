# FIXIS — QA fisico de acceso por correo

Estado: PENDING. Ejecutar sobre compilaciones instaladas desde la rama actual.
No compartir codigos OTP ni capturas que los muestren. Registrar dispositivo, rol,
resultado y hora aproximada de cada caso. No crear pagos ni liquidaciones.

## 1. Ingreso y persistencia (iPhone 15, cuenta existente)

1. Cerrar sesion en una cuenta de cliente de pruebas que tenga acceso al buzón.
2. Pedir un codigo una sola vez y verificar que llegue. Introducirlo en la app.
3. Confirmar que abre el perfil del cliente y que los servicios pertenecen a esa cuenta.
4. Cerrar la app completamente y abrirla desde el icono: debe conservar la sesion.

## 2. Reenvio (Android, cuenta existente)

1. Cerrar sesion en una cuenta de pruebas con acceso al buzón.
2. Pedir un codigo; esperar a que termine el contador de 60 segundos.
3. Solicitar un unico reenvio, introducir el codigo del correo mas reciente.
4. Confirmar que entra al rol correcto. Evitar varios intentos seguidos por el
   limite de envio del proveedor.

## 3. Alta de cliente (Android, correo nuevo controlado)

1. Desde "Soy cliente: crear cuenta", registrar nombre y correo nuevo accesible.
2. Verificar el codigo y comprobar que el perfil queda como cliente.
3. Comprobar en Supabase Auth y profiles que hay un solo usuario/perfil vinculado.
4. Cerrar sesion y volver a entrar desde "Enviar Código de Acceso".

## 4. Correo asociado a otro rol (al final, cuenta de administrador controlada)

1. Salir de la sesion actual e iniciar el alta de cliente con el correo del
   administrador de pruebas.
2. Verificar el codigo recibido en ese buzón. Debe aparecer el aviso de que
   pertenece a otra cuenta y no debe crearse un segundo perfil de cliente.
3. Volver a la pantalla de ingreso y entrar como administrador.
   Este paso cierra temporalmente la sesion del dispositivo; hacerlo cuando
   no se este operando en el panel.

Criterio de cierre: pasos 1 a 4 correctos en las compilaciones indicadas,
sin cuentas duplicadas y sin exponer datos entre roles. Si falla el envio,
registrar el mensaje exacto, hora y si Supabase registro POST /auth/v1/otp;
HTTP 200 no demuestra por si solo que el correo se entrego.
