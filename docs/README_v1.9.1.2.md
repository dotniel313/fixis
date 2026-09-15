# FIXIS PRO v1.9.1.2 — UI + Evidence Stability Hotfix

## Problemas corregidos

### UI-003 — Login RenderFlex overflow
El login usaba un `Column` centrado no scrollable. En alturas reducidas
(por ejemplo con teclado visible) producía `RenderFlex OVERFLOWING`.

Corrección:
- LayoutBuilder
- SingleChildScrollView
- ConstrainedBox(minHeight)
- keyboardDismissBehavior onDrag

### JOB-IMG-001 — estabilidad de evidencia antes/después
Se confirmó que ambas fotos sí llegaban al bucket `evidencias_pro`, por lo que
Storage y sus policies no eran la causa.

El cliente Flutter se endurece para reducir presión de memoria y mejorar
diagnóstico:
- captura limitada a 1600x1600
- imageQuality 70
- preview con ResizeImage(width: 700)
- bloqueo de capturas múltiples simultáneas
- logs `[EVIDENCE]`
- liberación/evicción de previews después de finalizar
- no se cambia ningún bucket ni migración SQL

## Aplicación

Este paquete contiene `lib/` completa.

```bash
mv lib ../lib_backup_v1_9_1_1
# Copiar la lib/ completa del paquete
flutter clean
flutter pub get
flutter analyze
flutter run
```

No ejecutar SQL.

## Prueba
1. Login con teclado visible: no debe aparecer RenderFlex overflow.
2. Profesional inicia servicio.
3. Tomar foto ANTES.
4. Tomar foto DESPUÉS.
5. Completar trabajo.
6. Ver logs `[EVIDENCE]`.
7. Esperado: `work_completed` sin cierre de la app.
