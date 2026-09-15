# FIXIS PRO v1.10.7.2 — Customer Profile Visibility Fix

## Motivo

En prueba física de v1.10.7.1 el usuario reportó que no veía la pantalla
ni el acceso al perfil del cliente.

La revisión del paquete confirmó que la pantalla existía, pero para eliminar
cualquier ambigüedad de visibilidad esta versión hace el acceso explícito.

## Cambios

- Botón visible `Mi perfil` en la cabecera del Customer Home.
- Tarjeta visible `Mi perfil · Datos, foto, actividad y cuenta` debajo del hero.
- Ambos accesos abren `CustomerProfileScreen`.
- Se conserva avatar con cámara/galería.
- Se conserva edición de nombre/teléfono/ciudad.
- Se conserva actividad, legal, soporte y logout.

## SQL

**NO requiere SQL.**

## Aplicación recomendada

No mezclar archivos sueltos. Sustituye la `lib/` completa de tu proyecto por
la `lib/` incluida en este paquete.

Después:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Qué debes ver

En el Home del cliente deben existir DOS accesos visibles:

1. Arriba a la derecha: `Mi perfil`.
2. Debajo del hero: tarjeta `Mi perfil`.

Al entrar:
- avatar;
- nombre;
- correo;
- teléfono;
- ciudad;
- actividad;
- cuenta;
- fidelización futura;
- legal/soporte;
- cerrar sesión.

## Prueba avatar

Tocar la foto → Cámara o Galería → seleccionar → volver a abrir perfil y
confirmar persistencia.
