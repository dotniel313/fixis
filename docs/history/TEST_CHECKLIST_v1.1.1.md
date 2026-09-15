# TEST CHECKLIST — FIXIS PRO v1.1.1

## Login
- [ ] Abrir app sin sesión muestra Login.
- [ ] Enviar código OTP funciona.
- [ ] Verificar OTP válido entra a la app.
- [ ] Medir perceptivamente si la espera después del OTP disminuyó frente a v1.1.0.
- [ ] Código inválido muestra error y no entra.

## Auth Gate
- [ ] Profesional `approved + active` entra al Dashboard.
- [ ] `verification_status = pending` muestra pantalla de verificación.
- [ ] `account_status = suspended` muestra cuenta suspendida.
- [ ] Restaurar los estados de prueba a `approved + active`.

## Dashboard
- [ ] Dashboard aparece correctamente.
- [ ] Nombre/avatar pueden cargar de forma independiente sin bloquear la pantalla.
- [ ] Radar mantiene funcionamiento.
- [ ] Aceptar trabajo sigue usando `accept_job()`.

## Sesión
- [ ] Cerrar sesión vuelve al Login.
- [ ] Volver a entrar no reutiliza datos de autorización de la sesión anterior.

## Regresión
- [ ] Billetera abre.
- [ ] Gamificación abre.
- [ ] Perfil abre.
- [ ] Job detail abre.
- [ ] `complete_job_v1()` sigue funcionando.
