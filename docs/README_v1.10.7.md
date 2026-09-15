# FIXIS PRO v1.10.7 — Customer Profile Premium

## Hallazgo de regresión

La prueba completa en dos iPhone confirmó que el flujo principal funciona,
pero el cliente todavía no tenía una pantalla propia de perfil.

Esta versión cierra ese hueco antes de Android/RC1.

## Incluye

### Mi perfil Cliente
- Nombre real.
- Correo autenticado.
- Teléfono.
- Ciudad.
- Estado de cuenta.
- Fecha de registro.
- Servicios activos.
- Servicios completados.
- Edición de nombre/teléfono/ciudad.
- Legal y soporte.
- Cierre de sesión.

### Home Cliente
- El botón superior derecho ahora abre `Mi perfil`.
- El cierre de sesión queda dentro del perfil, igual que en una app comercial madura.

### Fidelización
Se agrega una sección informativa que deja preparada la UX para una futura
fase CRM/loyalty, sin inventar puntos, rangos ni recompensas.

## Backend

**NO requiere SQL.**

Reutiliza:
- `profiles`
- `userProfileProvider`
- `myCustomerJobsProvider`
- Auth actual

No cambia:
- jobs
- quotes
- payments
- tracking
- FIXIS Live
- settlements
- ledger
- RLS
- RPCs

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación

1. Entrar como cliente.
2. Tocar icono de perfil arriba a la derecha.
3. Confirmar nombre/correo/teléfono/ciudad.
4. Confirmar activos y completados.
5. Editar nombre/teléfono/ciudad y guardar.
6. Regresar al Home y confirmar que el saludo refleja el nombre actualizado.
7. Verificar cierre de sesión desde Perfil.

## Estado posterior

Si esta versión pasa:
- iOS core: aprobado.
- perfil cliente: cerrado.
- siguiente paso: Android físico + RC1.
