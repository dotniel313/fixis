# Calificación bilateral y fidelización — validación v1.10.8.8

## Instalación

1. Migración 033 ya aplicada y verificada. Aplicar `supabase/migrations/034_rating_recipient_identity_v1_10_8_8.sql` una sola vez para mostrar el nombre y la foto de quien recibe la calificación.
2. Ejecutar `supabase/qa/FIXIS_RATINGS_LOYALTY_READONLY.sql`: los siete indicadores del primer bloque deben ser `true`; los dos conteos del segundo, cero; y los tres indicadores del tercer bloque, `true` después de la migración 034.
3. Actualizar la rama en el Mac, ejecutar `flutter analyze` y compilar la app de cliente y profesional. Esta etapa no se ha ejecutado desde el entorno de edición.

## Recorrido con cuentas reales

1. Abrir un servicio que ya figure `customer_approved` y cuyo pago esté `paid`. El cliente entra desde su historial y califica al FIXI de 1 a 5, con comentario opcional de hasta 500 caracteres.
2. Comprobar que la pantalla muestra el nombre y la foto del FIXI; si no tiene foto, muestra la silueta. Un usuario ajeno no debe obtener nombre ni foto llamando a `get_rating_recipient` con el ID del servicio. Si la consulta de identidad falla, se conserva el texto genérico y aún se puede calificar.
3. El profesional entra a **Mi actividad → Servicios confirmados**, abre ese mismo servicio y califica al cliente. Verificar que cada autor ve su calificación guardada y que un segundo intento no crea otra fila.
4. En cada perfil, comprobar que el promedio y el número de calificaciones recibidas corresponden solo a valoraciones reales.
5. Un servicio sin pago `paid`, un tercero o una cuenta no activa no debe poder enviar calificaciones; la validación se hace en `submit_job_rating`, además de ocultar el botón en la interfaz.
6. En perfil del cliente, el número de servicios pagados y categorías debe corresponder a la base. Los reconocimientos se calculan a partir de ese contador: desde 3, **Cliente recurrente**; desde 10, **Cliente habitual**. No hay saldo, descuentos ni canjes.
7. Si un pago deja de estar `paid` por reembolso, el contador de fidelización deja de incluir ese pago. Las calificaciones históricas permanecen registradas.

## Condición de cierre

Mantener calificación bilateral y fidelización en `PENDING` hasta aplicar 034, aprobar `flutter analyze` y completar ambos recorridos con usuarios reales. La liquidación del profesional es un flujo financiero independiente.
