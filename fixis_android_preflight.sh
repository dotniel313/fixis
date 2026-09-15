#!/usr/bin/env bash
set -u

OUT="fixis_android_preflight_report.txt"
: > "$OUT"

log() {
  printf "%s\n" "$*" | tee -a "$OUT"
}

section() {
  log ""
  log "============================================================"
  log "$1"
  log "============================================================"
}

section "FIXIS ANDROID PREFLIGHT"
log "Fecha: $(date)"
log "Directorio: $(pwd)"

if [ ! -f "pubspec.yaml" ]; then
  log "ERROR: Ejecuta este script desde la raíz del proyecto Flutter (donde está pubspec.yaml)."
  exit 1
fi

section "FLUTTER / DART"
flutter --version 2>&1 | tee -a "$OUT" || true
dart --version 2>&1 | tee -a "$OUT" || true
flutter doctor -v 2>&1 | tee -a "$OUT" || true

section "PROYECTO"
grep -E '^name:|^version:' pubspec.yaml 2>/dev/null | tee -a "$OUT" || true

section "DEPENDENCIAS RELEVANTES"
grep -E 'supabase_flutter|geolocator|image_picker|flutter_map|url_launcher|connectivity_plus|drift|sqlite|permission_handler|app_links|uni_links' pubspec.yaml 2>/dev/null | tee -a "$OUT" || true

section "ANDROID FILES"
for f in \
  android/app/src/main/AndroidManifest.xml \
  android/app/build.gradle \
  android/app/build.gradle.kts \
  android/build.gradle \
  android/build.gradle.kts \
  android/gradle.properties \
  android/settings.gradle \
  android/settings.gradle.kts
do
  if [ -f "$f" ]; then
    log "FOUND: $f"
  else
    log "MISSING/NOT USED: $f"
  fi
done

section "ANDROID MANIFEST — PERMISSIONS / DEEP LINKS"
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  grep -nE 'uses-permission|uses-feature|intent-filter|scheme=|host=|android:name=' "$MANIFEST" 2>/dev/null | tee -a "$OUT" || true
else
  log "AndroidManifest.xml no encontrado."
fi

section "ANDROID SDK / APPLICATION ID"
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    log "--- $f ---"
    grep -nE 'namespace|applicationId|minSdk|targetSdk|compileSdk|versionCode|versionName|signingConfig' "$f" 2>/dev/null | tee -a "$OUT" || true
  fi
done

section "LOCAL PROPERTIES"
if [ -f "android/local.properties" ]; then
  grep -E 'flutter.sdk|sdk.dir' android/local.properties 2>/dev/null | sed 's#=.*#=<configured>#' | tee -a "$OUT" || true
else
  log "android/local.properties no encontrado."
fi

section "PERMISOS ESPERADOS POR FIXIS"
cat <<'EOF' | tee -a "$OUT"
Revisar según funciones usadas:
- android.permission.INTERNET
- android.permission.ACCESS_FINE_LOCATION
- android.permission.ACCESS_COARSE_LOCATION
- CAMERA (si el flujo/captura lo requiere explícitamente)
- permisos de imágenes modernos si alguna librería los necesita
Nota: image_picker moderno suele delegar selección al sistema; no agregar permisos antiguos de almacenamiento sin necesidad.
EOF

section "DISPOSITIVOS"
flutter devices 2>&1 | tee -a "$OUT" || true
adb devices -l 2>&1 | tee -a "$OUT" || true

section "ANALYZE"
flutter analyze 2>&1 | tee -a "$OUT"
ANALYZE_CODE=${PIPESTATUS[0]}
log "flutter analyze exit code: $ANALYZE_CODE"

section "DEBUG APK BUILD"
flutter build apk --debug 2>&1 | tee -a "$OUT"
APK_CODE=${PIPESTATUS[0]}
log "flutter build apk --debug exit code: $APK_CODE"

section "APPBUNDLE RELEASE DRY CHECK"
log "No se ejecuta build release firmado automáticamente para no tocar signing."
log "Cuando signing esté confirmado, usar: flutter build appbundle --release"

section "RESUMEN"
if [ "$ANALYZE_CODE" -eq 0 ]; then
  log "ANALYZE: OK"
else
  log "ANALYZE: REVISAR"
fi

if [ "$APK_CODE" -eq 0 ]; then
  log "DEBUG APK: OK"
  if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    log "APK: build/app/outputs/flutter-apk/app-debug.apk"
  fi
else
  log "DEBUG APK: REVISAR"
fi

log ""
log "Reporte generado: $OUT"
