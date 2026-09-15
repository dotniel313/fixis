# Validación técnica v1.8.5.2

## Verificaciones realizadas
- Búsqueda de residuos demo críticos (`142.50`, `Platino`, mensaje Financial Core pendiente): sin coincidencias activas en `lib/`.
- Búsqueda de coordenadas fallback `-0.1764,-78.4805`: sin coincidencias activas en `lib/`.
- Documentación histórica separada de la baseline vigente.
- Script de reconciliación Supabase añadido y marcado como solo lectura.

## Verificación no ejecutable en este snapshot
No se pudo ejecutar `flutter analyze` porque el ZIP fuente no contiene `pubspec.yaml` ni `analysis_options.yaml`. La validación de compilación debe hacerse al integrar este paquete en la raíz real del proyecto Flutter.

## Próxima comprobación obligatoria
1. Copiar los archivos estabilizados sobre la raíz real.
2. Ejecutar `flutter pub get`.
3. Ejecutar `flutter analyze`.
4. Ejecutar `supabase/reconciliation/001_extract_live_backend.sql` en Supabase SQL Editor.
5. Guardar/compartir los resultados para reconstruir el historial de migraciones faltantes.
