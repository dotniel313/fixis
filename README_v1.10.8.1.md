# FIXIS PRO v1.10.8.1 — Analyzer Cleanup

Patch sobre v1.10.8.0 orientado exclusivamente a limpiar los 25 hallazgos reportados por `flutter analyze`.

- elimina `_logout` no usado en Admin Payments;
- sustituye `ref.refresh(...future)` no consumido por `ref.invalidate(...)`;
- aplica `const` donde el analyzer lo recomienda;
- corrige los tres avisos `use_build_context_synchronously` usando el `State.context` protegido por `mounted`;
- no modifica Supabase, esquema, RPCs ni lógica financiera;
- no modifica configuración nativa iOS.

Validar en Mac con:

```bash
flutter pub get
flutter analyze
```

Resultado esperado: `No issues found!`
