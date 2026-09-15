# FIXIS PRO v1.10.6 — Admin Account + Premium Polish + Regression Freeze

## Mi cuenta Admin

Se agrega una pantalla administrativa interna que reutiliza el perfil existente:

- nombre;
- correo;
- rol;
- estado de cuenta;
- acceso protegido;
- explicación de trazabilidad;
- cierre de sesión.

No es un perfil público ni comercial.

## Permisos

Esta versión NO implementa todavía permisos granulares como:
- finance_admin
- operations_admin
- support_admin

Eso queda para una fase posterior de seguridad/organización si FIXIS lo necesita.

## Freeze funcional

A partir de v1.10.6 se congela el core para iniciar QA multiplataforma.

No agregar nuevas funcionalidades antes de cerrar:
1. regresión iOS;
2. pruebas Android físico;
3. bugs P0/P1;
4. Release Candidate.

## SQL

**NO requiere SQL.**

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Próximo hito

**FIXIS PRO v2.0 RC1**

antes de RC1:
- regresión integral;
- Android físico;
- build release;
- seguridad final.
