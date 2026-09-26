# Calificación bilateral y fidelización — validación v1.10.8.8

## Instalación

1. Migraciones 033 y 034 aplicadas. El 2026-09-26 el usuario confirmo los siete `true` del bloque 1, dos ceros del bloque 2 y tres `true` del bloque 3.
2. Repetir `supabase/qa/FIXIS_RATINGS_LOYALTY_READONLY.sql` tras las pruebas de calificacion: siete `true` en bloque 1, dos ceros en bloque 2 y tres `true` en bloque 3.
3. CI 36254445169 paso el generador de iconos, `flutter analyze` y `flutter build apk --debug` con `.env` de prueba. Falta instalar una compilacion actualizada en dispositivos reales y validar ambos roles.

## Recorrido con cuentas reales

1. Abrir un servicio que ya figure `customer_approved` y cuyo pago esté `paid`. El cliente entra desde su historial y califica al FIXI de 1 a 5, con comentario opcional de hasta 500 caracteres.
2. Comprobar que la pantalla muestra el nombre y la foto del FIXI; si no tiene foto, muestra la silueta. Un usuario ajeno no debe obtener nombre ni foto llamando a `get_rating_recipient` con el ID del servicio. Si la consulta de identidad falla, se conserva el texto genérico y aún se puede calificar.
3. El profesional entra a **Mi actividad → Servicios confirmados**, abre ese mismo servicio y califica al cliente. Verificar que cada autor ve su calificación guardada y que un segundo intento no crea otra fila.
4. En cada perfil, comprobar que el promedio y el número de calificaciones recibidas corresponden solo a valoraciones reales.
5. Un servicio sin pago `paid`, un tercero o una cuenta no activa no debe poder enviar calificaciones; la validación se hace en `submit_job_rating`, además de ocultar el botón en la interfaz.
6. En perfil del cliente, el número de servicios pagados y categorías debe corresponder a la base. Los reconocimientos se calculan a partir de ese contador: desde 3, **Cliente recurrente**; desde 10, **Cliente habitual**. No hay saldo, descuentos ni canjes.
7. Si un pago deja de estar `paid` por reembolso, el contador de fidelización deja de incluir ese pago. Las calificaciones históricas permanecen registradas.

## Avance confirmado el 2026-09-26

- Cliente a FIXI y FIXI a cliente: ambos recorridos guardados para el mismo servicio, con calificación visible en los perfiles respectivos.
- Aislamiento de identidad y reseñas: simulación de tercero y prueba física con dos cuentas distintas confirmadas. En iPhone, el FIXI ve la reseña recibida con nombre, foto y comentario.
- Fidelización cliente: una cuenta Android muestra 1 servicio pagado, 1 categoría y progreso hacia el reconocimiento de 3 pagos. El rango profesional Inicial muestra 2/5 servicios.
- Pendiente: primera consulta de permisos de `supabase/qa/FIXIS_RECEIVED_REVIEWS_READONLY.sql`; pantalla de reseñas recibidas en cliente y Android; umbrales de 3 y 10 pagos; aislamiento físico de trabajos y pagos, y repetición de los conteos tras nuevas calificaciones.

La liquidación del profesional es un flujo financiero independiente. No marcar producción lista hasta cerrar los controles financieros y de seguridad de `docs/QA_MATRIX.md`.
