# FIXIS PRO v1.10.3 — Perfil + Nivel FIXIS Premium

## Perfil profesional

- Hero premium azul midnight + naranja.
- Avatar editable preservado.
- Estado VERIFICADO.
- Calificación y trabajos confirmados.
- Acceso directo a Nivel FIXIS.
- Biografía editable preservada.
- Información profesional.
- Cuenta bancaria enmascarada y privada.
- Seguridad, legal, soporte, cierre de sesión y eliminación de cuenta preservados.

## Nivel FIXIS

- Identidad premium consistente.
- Rango real desde `expert_gamification.current_rank`.
- Servicios confirmados reales.
- Meta y progreso solo cuando existen datos válidos.
- No se inventan insignias ni beneficios.
- Explicación clara de cómo se construye el progreso.

## Backend

**NO requiere SQL.**

No modifica:
- profiles schema
- expert_gamification schema
- RLS
- RPC
- pagos
- ledger
- settlements
- jobs

## Aplicación

Reemplazar `lib/` completa:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Validación mínima

1. Abrir Perfil.
2. Confirmar nombre, categoría, rating y trabajos.
3. Confirmar cuenta bancaria enmascarada.
4. Abrir Nivel FIXIS desde Perfil.
5. Confirmar rango y progreso real.
6. Editar biografía.
7. Volver al dashboard.
