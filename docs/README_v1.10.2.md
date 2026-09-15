# FIXIS PRO v1.10.2 — Wallet + Notifications Premium

## Alcance

Segunda migración visual de la fase premium.

### Wallet
- Cabecera y balance principal alineados a identidad FIXIS.
- Azul midnight + naranja de marca.
- Métricas con color semántico.
- Próximo corte, cuenta bancaria, liquidaciones y ganancias con superficies premium.
- Conserva `get_wallet_summary` y `get_professional_payout_schedule`.
- Conserva cancelación legacy únicamente donde ya estaba permitida.

### Notificaciones
- Hero premium con contador de novedades.
- Indicador `REALTIME`.
- Tarjetas con estados visuales:
  - Liquidación
  - Procesando
  - Pagado
  - Revisar
- Mantiene lectura individual y "Leer todas".
- Mantiene `myNotificationsStreamProvider`, RLS y Supabase Realtime.

## Backend

**NO requiere SQL.**

No cambia:
- payments
- ledger
- settlements
- notifications trigger
- RLS
- RPC
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

1. Abrir Billetera.
2. Confirmar saldo, reservado, ganado y retirado.
3. Confirmar cuenta bancaria.
4. Confirmar liquidaciones históricas.
5. Abrir Notificaciones.
6. Confirmar eventos reales.
7. Marcar una como leída.
8. Usar `Leer todas`.
