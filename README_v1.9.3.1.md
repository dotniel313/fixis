# FIXIS PRO v1.9.3.1 — Real Settlement Notifications

## Objetivo

Reemplazar definitivamente el estado vacío/demo de notificaciones por eventos
reales provenientes de `settlements`.

## Eventos v1

- Liquidación semanal preparada
- Pago en procesamiento
- Transferencia pagada
- Liquidación rechazada

## Seguridad

- Cada profesional solo puede leer sus propias notificaciones.
- Flutter no puede crear ni eliminar notificaciones.
- Flutter solo puede actualizar `read_at`.
- Los eventos se generan desde un trigger backend `SECURITY DEFINER`.
- `idempotency_key` evita duplicados.

## Realtime

`public.notifications` se agrega a `supabase_realtime`.

El dashboard profesional muestra una campana con contador de no leídas.

## Histórico

Migration 027 hace backfill idempotente de liquidaciones reales ya existentes,
por lo que el pago histórico de US$255 debería aparecer inmediatamente como
notificación real.

## Instalación

1. Ejecutar:
   `027_real_settlement_notifications_v1_9_3_1.sql`
2. Ejecutar:
   `docs/VALIDATE_027.sql`
3. Reemplazar `lib/` completa.
4. Ejecutar:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Prueba mínima

1. Entrar como profesional.
2. Ver campana con badge.
3. Abrir Notificaciones.
4. Confirmar evento real de liquidación/pago.
5. Tocar la notificación y comprobar que desaparece del contador.
6. Usar "Marcar leídas" y comprobar badge = 0.
