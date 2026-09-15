# FIXIS PRO v1.8.5.1 — Compile Hotfix

Correcciones sobre v1.8.5:
- Reubica los manejadores de error FIXIS Live dentro de `_mapRpcException()` en `jobs_repository.dart`.
- Corrige `prefer_const_constructors` en `dashboard_screen.dart`.
- Corrige uso de `BuildContext` después de `await` en `job_detail_screen.dart` con una nueva comprobación de `mounted`.

No requiere migraciones de Supabase ni nuevas dependencias.

## Validación

```bash
flutter clean
flutter pub get
flutter analyze
```

Objetivo: `No issues found!`
