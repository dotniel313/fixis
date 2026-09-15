# FIXIS PRO v1.10.6 — Regression Freeze Checklist

## Regla de freeze

Desde esta versión no agregar nuevas funciones al core antes de completar QA.
Solo se permiten:
- correcciones de bugs;
- ajustes visuales menores;
- compatibilidad iOS/Android;
- seguridad;
- rendimiento.

## Auth
- [ ] OTP profesional
- [ ] OTP cliente
- [ ] login admin
- [ ] cooldown 60 s
- [ ] logout por rol

## Profesional
- [ ] Dashboard premium
- [ ] Radar OFF
- [ ] Radar ON + ubicación
- [ ] 5/8/15/25 km
- [ ] oportunidades
- [ ] aceptar trabajo
- [ ] Mi actividad
- [ ] Perfil
- [ ] Nivel FIXIS
- [ ] Wallet
- [ ] Notificaciones

## Job E2E
- [ ] cliente crea job
- [ ] FIXI acepta
- [ ] cotiza
- [ ] cliente acepta cotización
- [ ] autorizado
- [ ] en route
- [ ] ruta + ETA
- [ ] arrived
- [ ] in progress
- [ ] work completed
- [ ] cliente aprueba
- [ ] job sale de activos
- [ ] job entra a historial

## Pagos
- [ ] cliente registra pago
- [ ] voucher privado
- [ ] admin visualiza evidencia
- [ ] admin verifica
- [ ] payment paid
- [ ] professional earning
- [ ] platform commission
- [ ] idempotencia

## Wallet / Settlements
- [ ] saldo disponible
- [ ] saldo reservado
- [ ] ganado histórico
- [ ] retirado
- [ ] próximo corte
- [ ] generar liquidación
- [ ] processing
- [ ] paid
- [ ] payout_reference
- [ ] settlement_debit único
- [ ] audit RPC

## Notifications
- [ ] settlement_created
- [ ] settlement_processing
- [ ] settlement_paid
- [ ] settlement_rejected
- [ ] badge unread
- [ ] marcar una
- [ ] marcar todas

## Admin
- [ ] Verificar
- [ ] Historial
- [ ] Liquidaciones
- [ ] Ingresos FIXIS
- [ ] saldo plataforma
- [ ] detalle comisiones
- [ ] Mi cuenta Admin
- [ ] rol/estado/email correctos

## iOS
- [ ] cámara
- [ ] ubicación
- [ ] mapas
- [ ] permisos
- [ ] background / resume
- [ ] instalación limpia
- [ ] build release

## Android
- [ ] instalación física
- [ ] cámara
- [ ] ubicación
- [ ] mapas
- [ ] permisos runtime
- [ ] back navigation
- [ ] teclado
- [ ] deep/auth links
- [ ] background / resume
- [ ] build release

## Criterio RC1

No bugs P0/P1 abiertos.
Flujo E2E completo exitoso al menos 3 veces consecutivas.
Ledger y settlements auditados.
iOS + Android físico aprobados.
