# FIXIS PRO v1.6.1 — Customer Foundation

- Auth Gate ahora resuelve `professional` y `customer`.
- Registro OTP específico para cliente con `full_name` y `phone` en metadata.
- Nuevo Home Cliente.
- Nueva creación de solicitudes mediante RPC `create_job()`.
- Cliente ve exclusivamente sus jobs mediante RLS.
- Revisión de cotizaciones enviadas.
- Aceptación mediante `accept_quote_customer()`.
- Confirmación de trabajo mediante `approve_completed_job()`.
- Se mantienen separados Dashboard profesional y experiencia cliente.
- No se agregan escrituras directas de Flutter sobre `jobs` o `quotes`.
