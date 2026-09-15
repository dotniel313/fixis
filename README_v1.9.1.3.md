# FIXIS PRO v1.9.1.3 — Admin Dialog Stability Hotfix

## Correcciones

### ADMIN-UI-001
Assertion Flutter:
`_dependents.isEmpty: is not true`

Causa corregida:
- `TextEditingController` creados fuera de `showDialog`
- `dispose()` inmediato al cerrar rutas modales
- `autofocus` innecesario en rechazo

Cambios:
- Confirmar acreditación usa valores locales `onChanged`
- Rechazar comprobante usa valor local `onChanged`
- Sin `TextEditingController`
- Sin `autofocus`
- `mounted` comprobado antes de continuar

### AUTH-LINT-001
Se corrigen los warnings de Riverpod:
`The value of 'refresh' should be used`

Ahora:
`await ref.refresh(appAccessProvider.future);`

## Backend
No hay migración SQL.
No cambia Supabase.
No cambia Payments.
No cambia Storage.

## Aplicación

Este paquete contiene la `lib/` completa.

```bash
mv lib ../lib_backup_v1_9_1_2
# copiar la lib/ completa de este paquete
flutter clean
flutter pub get
flutter analyze
flutter run
```

Esperado:
`No issues found!`

## Validación
1. Entrar como admin.
2. Por verificar.
3. Abrir comprobante.
4. Rechazar → escribir motivo → Rechazar.
5. No debe aparecer pantalla roja.
6. Crear otro pago pendiente.
7. Confirmar acreditación → completar campos → Confirmar pago.
8. No debe aparecer assertion.
