# FIXIS — aislamiento con cuentas reales

Esta prueba es de lectura: no crea servicios ni mueve dinero.

## Preparacion

Identificar dos cuentas de cliente distintas, A y B, con al menos un servicio
confirmado en cada una. Anotar solo el titulo/ID del servicio propio; no
compartir correos, codigos OTP ni datos bancarios en capturas.

## Prueba en telefonos

1. Entrar como cliente A: en Mis servicios debe verse el servicio de A.
   Abrirlo y comprobar que su estado de pago corresponde a A.
2. Cerrar sesion; entrar como cliente B en el mismo telefono: el servicio
   de A y su pago no deben aparecer. El servicio de B debe verse.
3. Con la cuenta profesional, entrar en Mi actividad y Mi billetera:
   mostrar solo trabajos asignados y ganancias propias.
4. Con la cuenta administradora, consultar Pagos y Liquidaciones:
   debe conservar la vista administrativa de las operaciones.

Resultado esperado: ninguna cuenta muestra servicios/pagos ajenos y cada una
mantiene visibles sus datos propios. La prueba no incluye registrar una
transferencia ni marcar como pagada una liquidacion.

Las consultas Flutter de cliente filtran tambien por client_id/customer_id;
las politicas RLS permanecen como barrera de servidor.
