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

## Resultados confirmados el 2026-09-26

- Controles SQL con roles simulados: cliente ve pago propio y no ve pagos ajenos ni liquidaciones; profesional ve solo sus ganancias y su liquidacion, no la comision FIXIS; administrador ve todos los pagos y liquidaciones.
- En iPhone 15 Pro, la cuenta cliente Jhony Torres no muestra servicios de Maria Jose; el usuario confirma la ausencia. Capturas de Jhony muestran su perfil, reseña propia 3/5, servicio propio tuberia dañada y mensaje de pago confirmado.
- La compilacion actual de iPhone 15 Pro muestra el texto de pago corregido. QA Android con compilacion actual sigue abierto por separado.

La prueba no marca como pagada ninguna liquidacion al profesional.
