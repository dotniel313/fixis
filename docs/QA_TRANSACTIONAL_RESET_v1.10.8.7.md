# FIXIS — QA Transactional Reset v1.10.8.7

Fecha: 2026-09-16

## Estado

PASS

## Objetivo

Eliminar exclusivamente los datos transaccionales de prueba antes de ejecutar
el QA limpio del flujo Revised Quote, conservando identidades, configuracion,
seguridad y estructura del backend.

## Estado inicial auditado

| Entidad | Cantidad |
|---|---:|
| jobs | 12 |
| payments | 6 |
| platform_commission | 9 |
| settlements | 5 |

Se identificaron tres entradas de comision por USD 4.50 sin payment asociado.
Estas entradas pertenecian al historial de prueba y estaban registradas en
financial_ledger_entries.

## Protecciones aplicadas

- Respaldo persistente: fixis_backup_reset_20260916
- Validacion de conteos iniciales
- Comparacion exacta de IDs de jobs contra el respaldo
- Orden de borrado conforme a claves foraneas RESTRICT
- Reinicio de estadisticas derivadas de perfiles y gamificacion afectados
- Conservacion de auth.users, profiles, commission_rules, financial_accounts,
  RLS, RPC y migraciones
- Script almacenado como herramienta QA, no como migracion automatica

## Evidencia

1. Ensayo transaccional con ROLLBACK: PASS
2. Conteos durante el ensayo: todos en cero
3. Restauracion posterior al ROLLBACK: 12 jobs, 6 payments,
   9 commissions y 5 settlements
4. Respaldo verificado: 12 jobs, 6 payments, 9 commissions y 5 settlements
5. Ejecucion definitiva con COMMIT: PASS
6. Verificacion final: jobs, quotes, snapshots, ledger, payments,
   commissions, settlements y settlement_items en cero

## Resultado final

| jobs | quotes | snapshots | ledger | payments | commissions | settlements | settlement_items |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Siguiente paso

Ejecutar desde una base transaccional limpia el QA end-to-end de Revised Quote
y la regresion financiera quote -> snapshot -> payment -> ledger -> settlement.
