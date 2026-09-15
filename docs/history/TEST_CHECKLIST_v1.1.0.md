# Checklist de pruebas — FIXIS PRO v1.1.0

## Backend
- [ ] Ejecutar `003_job_actions_v1_1_0.sql` sin errores.
- [ ] Confirmar `complete_job_v1` como `SECURITY DEFINER`.
- [ ] Confirmar que `authenticated` no tiene UPDATE sobre `jobs`.

## Autenticación
- [ ] Daniel recibe OTP y entra al Dashboard.
- [ ] Patricia recibe OTP y entra al Dashboard.
- [ ] Correo no registrado no crea una cuenta nueva.
- [ ] Cerrar sesión devuelve al login.

## Roles / estados
- [ ] `verification_status = pending` muestra pantalla de verificación.
- [ ] `account_status = suspended` bloquea Dashboard.
- [ ] Restaurar el perfil de prueba a `approved/active` después de probar.

## Jobs
- [ ] Radar lista trabajos `pending`.
- [ ] Aceptar trabajo ejecuta RPC y abre detalle.
- [ ] Segundo intento sobre el mismo job devuelve "Otro FIXI ya tomó este trabajo".
- [ ] Subir evidencia sigue funcionando.
- [ ] Completar trabajo cambia `in_progress` a `completed` mediante RPC.

## Regresión
- [ ] Perfil abre correctamente.
- [ ] Billetera se puede leer.
- [ ] Gamificación se puede leer.
- [ ] Navegación GPS sigue funcionando.
