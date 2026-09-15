# FIXIS — QA Matrix

## Estados

- PASS
- FAIL
- PENDING
- BLOCKED

## Release actual

| Área | Estado |
|---|---|
| Flutter Analyze | PENDING |
| Flutter Test | PENDING |
| Android Build | PENDING |
| Android Physical QA | PENDING |
| iOS Build | PENDING |
| iOS Physical QA | PENDING |
| Supabase Validation | PENDING |
| Revised Quote Flow | PENDING |
| Finance Regression | PENDING |
| Security Regression | PENDING |

## Criterios v1.10.8.6

- Preserva cotización original
- Revisión solo en `arrived`
- Motivo obligatorio
- Cliente visualiza comparación
- Rechazo conserva snapshot anterior
- Aceptación crea snapshot vigente
- Solo un snapshot current
- Revisión pendiente bloquea start_job
- Payment usa snapshot vigente
- Ledger usa snapshot vigente
- No duplica earning
- No duplica commission
